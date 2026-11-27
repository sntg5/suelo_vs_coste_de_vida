-- =============================================================================
-- 02 · Utilidades de carga en PRO_BRONZE_DB.UTILS
-- =============================================================================
-- Stage, 2 file formats, 2 funciones (UDF), tabla de auditoría y procedimiento
-- de carga. Todo se copia a DEV con el clon (04_clonar_bronze.sql).
-- Dentro de las funciones y del procedimiento no hay nombres de database
-- escritos: el procedimiento recibe la tabla con su database (PRO o DEV) y
-- carga en ella con el stage y el file format de esa misma database.
-- Se puede ejecutar varias veces: el stage y la auditoría se conservan ("if not
-- exists") y lo demás se sustituye ("or replace").
-- =============================================================================

use role sysadmin;
use warehouse WH_CURSO;
use schema PRO_BRONZE_DB.UTILS;

-- 1. Stage interno donde se suben los 4 ficheros de origen
create stage if not exists CARGA_BRONZE
    comment = 'Ficheros de origen: 36400500.csv, 36100500.csv, 50918.csv y 6150.csv';

-- 2. File formats. Los 4 ficheros usan ";" como separador y UTF-8 con BOM.
--    El nombre es FF_ + esquema de destino, y así lo elige el procedimiento.
--    · FF_MIVAU no salta ninguna fila: se carga la hoja entera del ministerio y
--      _fila coincide con la fila de Excel.
--    · FF_INE salta la fila de cabecera.
create or replace file format FF_MIVAU
    type = csv
    field_delimiter = ';'
    skip_header = 0
    encoding = 'UTF8'
    field_optionally_enclosed_by = '"'
    comment = 'CSV convertidos del ministerio (tablas 4 y 1): hoja completa';

create or replace file format FF_INE
    type = csv
    field_delimiter = ';'
    skip_header = 1
    encoding = 'UTF8'
    field_optionally_enclosed_by = '"'
    comment = 'CSV del INE (tablas 50918 y 6150): salta la cabecera';

-- 3. Funciones. Las usan los modelos stg_ de dbt.

-- Texto con número en formato español → NUMBER. Sirve para las 4 fuentes:
--   1) "n.s.", "n.s", "." y ".." (sin dato) → NULL
--   2) quita el punto de miles (54.548 → 54548)
--   3) cambia la coma decimal por punto (119,942 → 119.942)
--   4) TRY_TO_NUMBER devuelve NULL si el texto no es un número
-- NUMBER(38,12) es exacto y no redondea el dato de origen. El tipo final lo
-- fija cada modelo slv_.
create or replace function FN_TEXTO_A_NUMERO(texto varchar)
    returns number(38, 12)
    language sql
    comment = 'Número en formato español (coma decimal, punto de miles, n.s.) a NUMBER'
as
$$
    case
        when trim(texto) in ('n.s.', 'n.s', '.', '..', '') then null
        else try_to_number(replace(replace(trim(texto), '.', ''), ',', '.'), 38, 12)
    end
$$;

-- Periodo mensual del INE ('2025M12') → primer día del mes (2025-12-01).
-- Si el periodo no es válido, devuelve NULL.
create or replace function FN_PERIODO_INE_A_FECHA(periodo varchar)
    returns date
    language sql
    comment = 'Periodo mensual del INE (AAAAMmm) a DATE del primer día del mes'
as
$$
    try_to_date(replace(trim(periodo), 'M', '-') || '-01', 'YYYY-MM-DD')
$$;

-- 4. Auditoría: una fila por cada carga, haya ido bien o mal
create table if not exists AUDITORIA_CARGAS (
      id_carga         number autoincrement start 1 increment 1   -- único, pero no garantiza el orden: se ordena por fin
    , base_datos       varchar        -- PRO_BRONZE_DB o DEV_BRONZE_DB
    , tabla            varchar        -- ESQUEMA.TABLA
    , fichero          varchar
    , filas_cargadas   number
    , estado           varchar        -- OK o ERROR
    , mensaje          varchar        -- descripción del error, si lo hay
    , sentencia        varchar        -- COPY INTO ejecutado
    , usuario          varchar        default current_user()
    , inicio           timestamp_ltz
    , fin              timestamp_ltz  default current_timestamp()
)
comment = 'Registro de las cargas de Bronze hechas con SP_CARGAR_BRONZE';

-- 5. Procedimiento de carga completa: TRUNCATE + COPY INTO.
--    · Parámetros: la tabla con su nombre completo (DATABASE.ESQUEMA.TABLA) y
--      el nombre del fichero. La database va siempre en la llamada: el
--      procedimiento no depende de la database en uso en la sesión. Carga desde
--      el stage y con el file format de esa misma database.
--    · Idempotente: TRUNCATE vacía la tabla y borra sus metadatos de carga, así
--      que el mismo fichero se puede volver a cargar con el mismo resultado.
--    · Las columnas de datos de la tabla se leen de INFORMATION_SCHEMA: la
--      columna i de la tabla recibe el campo i del fichero ($i).
--    · Se ejecuta con los derechos de su propietario (SYSADMIN).
--    · Registra cada carga en AUDITORIA_CARGAS de esa database y devuelve un
--      texto con el resultado (OK o ERROR).
-- Ejemplo: call PRO_BRONZE_DB.UTILS.SP_CARGAR_BRONZE('PRO_BRONZE_DB.MIVAU.PRECIO_SUELO', '36400500.csv');
create or replace procedure SP_CARGAR_BRONZE(tabla varchar, fichero varchar)
    returns varchar
    language sql
    comment = 'Carga completa de una tabla de Bronze (TRUNCATE + COPY INTO) con registro en AUDITORIA_CARGAS'
    execute as owner
as
$$
declare
    base            varchar;          -- database de la tabla (PRO_BRONZE_DB o DEV_BRONZE_DB)
    esquema         varchar;          -- MIVAU o INE
    nombre          varchar;          -- nombre de la tabla
    destino         varchar;          -- DATABASE.ESQUEMA.TABLA
    auditoria       varchar;          -- tabla de auditoría de esa database
    vista_columnas  varchar;          -- INFORMATION_SCHEMA.COLUMNS de esa database
    columnas        varchar;          -- columnas de datos de la tabla
    posiciones      varchar;          -- campos del fichero: $1, $2, ...
    sentencia       varchar;          -- COPY INTO que se ejecuta
    filas           number default 0;
    estado          varchar;
    mensaje         varchar;
    inicio          timestamp_ltz;
begin
    inicio  := current_timestamp();
    base    := upper(split_part(tabla, '.', 1));
    esquema := upper(split_part(tabla, '.', 2));
    nombre  := upper(split_part(tabla, '.', 3));

    if (nombre = '') then
        return 'ERROR · ' || tabla || ' · la tabla se indica como DATABASE.ESQUEMA.TABLA';
    end if;

    destino        := base || '.' || esquema || '.' || nombre;
    auditoria      := base || '.UTILS.AUDITORIA_CARGAS';
    vista_columnas := base || '.INFORMATION_SCHEMA.COLUMNS';

    -- 1. Columnas de datos de la tabla, en su orden (sin las 3 técnicas)
    select listagg(column_name, ', ') within group (order by ordinal_position),
           listagg('$' || ordinal_position, ', ') within group (order by ordinal_position)
      into :columnas, :posiciones
      from identifier(:vista_columnas)
     where table_schema = :esquema
       and table_name   = :nombre
       and column_name not in ('_FICHERO', '_FILA', '_LOADED_AT');

    -- 2. Vaciar la tabla
    truncate table identifier(:destino);

    -- 3. Cargar el fichero. _loaded_at no se menciona: toma su valor por defecto.
    sentencia := 'copy into ' || destino || ' (' || columnas || ', _FICHERO, _FILA)'
              || ' from (select ' || posiciones || ', metadata$filename, metadata$file_row_number'
              || ' from @' || base || '.UTILS.CARGA_BRONZE)'
              || ' files = (''' || fichero || ''')'
              || ' file_format = (format_name = ''' || base || '.UTILS.FF_' || esquema || ''')';
    execute immediate sentencia;

    -- 4. Filas cargadas (la tabla estaba vacía antes del COPY)
    select count(*) into :filas from identifier(:destino);
    if (filas > 0) then
        estado := 'OK';
    else
        estado  := 'ERROR';
        mensaje := 'No se ha cargado ninguna fila: el fichero no está en el stage';
    end if;

    -- 5. Registro en la auditoría
    insert into identifier(:auditoria)
        (base_datos, tabla, fichero, filas_cargadas, estado, mensaje, sentencia, inicio)
    select :base, :esquema || '.' || :nombre, :fichero, :filas, :estado, :mensaje, :sentencia, :inicio;

    return estado || ' · ' || destino || ' · ' || filas || ' filas · ' || fichero;

exception
    when other then
        mensaje := sqlerrm;
        insert into identifier(:auditoria)
            (base_datos, tabla, fichero, filas_cargadas, estado, mensaje, sentencia, inicio)
        select :base, :esquema || '.' || :nombre, :fichero, 0, 'ERROR', :mensaje, :sentencia, :inicio;
        return 'ERROR · ' || tabla || ' · ' || mensaje;
end;
$$;

-- Prueba de las funciones.
-- Resultado esperado: 159.7 · 54548 · NULL · 2025-12-01 · NULL
select FN_TEXTO_A_NUMERO('159,7')        as precio,
       FN_TEXTO_A_NUMERO('54.548')       as entero_con_miles,
       FN_TEXTO_A_NUMERO('n.s.')         as sin_dato,
       FN_PERIODO_INE_A_FECHA('2025M12') as periodo,
       FN_PERIODO_INE_A_FECHA('2025M13') as periodo_no_valido;
