-- =============================================================================
-- 03 · Tablas raw de Bronze y carga en PRO
-- =============================================================================
-- Crea las 4 tablas raw de PRO_BRONZE_DB y las carga con SP_CARGAR_BRONZE
-- (02_utilidades.sql). Los 4 ficheros deben estar en el stage
-- PRO_BRONZE_DB.UTILS.CARGA_BRONZE.
-- Reglas de las tablas raw:
--   · Las columnas de datos son todas VARCHAR. Los ficheros traen "n.s.", ".",
--     coma decimal y punto de miles; los tipos se fijan después en dbt.
--   · Las columnas de datos van primero y en el orden del fichero: el
--     procedimiento llena la columna i con el campo i.
--   · Al final, 3 columnas técnicas:
--       _fichero    nombre del fichero de origen
--       _fila       número de fila en el fichero. En las tablas del ministerio
--                   coincide con la fila de Excel; en las del INE no cuenta la
--                   cabecera.
--       _loaded_at  momento de la carga (valor por defecto). dbt la usa para
--                   comprobar la frescura de los datos (freshness).
--   · "if not exists": repetir el script no borra las tablas ni sus permisos.
--     Cada carga sustituye el contenido (TRUNCATE dentro del procedimiento).
-- =============================================================================

use role sysadmin;
use warehouse WH_CURSO;
use database PRO_BRONZE_DB;

-- =================================== TABLAS ==================================

-- MIVAU · tabla 4: precio medio del m² de suelo urbano (fichero 36400500.csv).
-- La hoja entera (83 filas × 94 columnas). Cada columna se llama como su letra
-- de Excel: COL_B + _fila señalan la celda exacta del original.
create table if not exists MIVAU.PRECIO_SUELO (
      COL_A   varchar -- columna A de Excel
    , COL_B   varchar -- nombre del territorio (nación, CCAA o provincia), con espacios finales
    , COL_C   varchar -- 1T 2004 (columnas C a CN: 90 trimestres, periodo por posición)
    , COL_D   varchar
    , COL_E   varchar
    , COL_F   varchar
    , COL_G   varchar
    , COL_H   varchar
    , COL_I   varchar
    , COL_J   varchar
    , COL_K   varchar
    , COL_L   varchar
    , COL_M   varchar
    , COL_N   varchar
    , COL_O   varchar
    , COL_P   varchar
    , COL_Q   varchar
    , COL_R   varchar
    , COL_S   varchar
    , COL_T   varchar
    , COL_U   varchar
    , COL_V   varchar
    , COL_W   varchar
    , COL_X   varchar
    , COL_Y   varchar
    , COL_Z   varchar
    , COL_AA  varchar
    , COL_AB  varchar
    , COL_AC  varchar
    , COL_AD  varchar
    , COL_AE  varchar
    , COL_AF  varchar
    , COL_AG  varchar
    , COL_AH  varchar
    , COL_AI  varchar
    , COL_AJ  varchar
    , COL_AK  varchar
    , COL_AL  varchar
    , COL_AM  varchar
    , COL_AN  varchar
    , COL_AO  varchar
    , COL_AP  varchar
    , COL_AQ  varchar
    , COL_AR  varchar
    , COL_AS  varchar
    , COL_AT  varchar
    , COL_AU  varchar
    , COL_AV  varchar
    , COL_AW  varchar
    , COL_AX  varchar
    , COL_AY  varchar
    , COL_AZ  varchar
    , COL_BA  varchar
    , COL_BB  varchar
    , COL_BC  varchar
    , COL_BD  varchar
    , COL_BE  varchar
    , COL_BF  varchar
    , COL_BG  varchar
    , COL_BH  varchar
    , COL_BI  varchar
    , COL_BJ  varchar
    , COL_BK  varchar
    , COL_BL  varchar
    , COL_BM  varchar
    , COL_BN  varchar
    , COL_BO  varchar
    , COL_BP  varchar
    , COL_BQ  varchar
    , COL_BR  varchar
    , COL_BS  varchar
    , COL_BT  varchar
    , COL_BU  varchar
    , COL_BV  varchar
    , COL_BW  varchar
    , COL_BX  varchar
    , COL_BY  varchar
    , COL_BZ  varchar
    , COL_CA  varchar
    , COL_CB  varchar
    , COL_CC  varchar
    , COL_CD  varchar
    , COL_CE  varchar
    , COL_CF  varchar
    , COL_CG  varchar
    , COL_CH  varchar
    , COL_CI  varchar
    , COL_CJ  varchar
    , COL_CK  varchar
    , COL_CL  varchar
    , COL_CM  varchar
    , COL_CN  varchar -- 2T 2026
    , COL_CO  varchar -- variación trimestral (se descarta en dbt)
    , COL_CP  varchar -- variación interanual (se descarta en dbt)
    , _fichero varchar
    , _fila    number
    , _loaded_at timestamp_ltz default current_timestamp()
)
comment = 'Raw MIVAU tabla 4 (precio medio del m² de suelo urbano, €/m²). Hoja completa; columnas por letra de Excel';

-- MIVAU · tabla 1: número de transacciones de suelo urbano (36100500.csv).
-- Misma estructura que la tabla 4 (85 filas × 94 columnas).
create table if not exists MIVAU.TRANSACCIONES_SUELO (
      COL_A   varchar -- columna A de Excel
    , COL_B   varchar -- nombre del territorio (nación, CCAA o provincia), con espacios finales
    , COL_C   varchar -- 1T 2004 (columnas C a CN: 90 trimestres, periodo por posición)
    , COL_D   varchar
    , COL_E   varchar
    , COL_F   varchar
    , COL_G   varchar
    , COL_H   varchar
    , COL_I   varchar
    , COL_J   varchar
    , COL_K   varchar
    , COL_L   varchar
    , COL_M   varchar
    , COL_N   varchar
    , COL_O   varchar
    , COL_P   varchar
    , COL_Q   varchar
    , COL_R   varchar
    , COL_S   varchar
    , COL_T   varchar
    , COL_U   varchar
    , COL_V   varchar
    , COL_W   varchar
    , COL_X   varchar
    , COL_Y   varchar
    , COL_Z   varchar
    , COL_AA  varchar
    , COL_AB  varchar
    , COL_AC  varchar
    , COL_AD  varchar
    , COL_AE  varchar
    , COL_AF  varchar
    , COL_AG  varchar
    , COL_AH  varchar
    , COL_AI  varchar
    , COL_AJ  varchar
    , COL_AK  varchar
    , COL_AL  varchar
    , COL_AM  varchar
    , COL_AN  varchar
    , COL_AO  varchar
    , COL_AP  varchar
    , COL_AQ  varchar
    , COL_AR  varchar
    , COL_AS  varchar
    , COL_AT  varchar
    , COL_AU  varchar
    , COL_AV  varchar
    , COL_AW  varchar
    , COL_AX  varchar
    , COL_AY  varchar
    , COL_AZ  varchar
    , COL_BA  varchar
    , COL_BB  varchar
    , COL_BC  varchar
    , COL_BD  varchar
    , COL_BE  varchar
    , COL_BF  varchar
    , COL_BG  varchar
    , COL_BH  varchar
    , COL_BI  varchar
    , COL_BJ  varchar
    , COL_BK  varchar
    , COL_BL  varchar
    , COL_BM  varchar
    , COL_BN  varchar
    , COL_BO  varchar
    , COL_BP  varchar
    , COL_BQ  varchar
    , COL_BR  varchar
    , COL_BS  varchar
    , COL_BT  varchar
    , COL_BU  varchar
    , COL_BV  varchar
    , COL_BW  varchar
    , COL_BX  varchar
    , COL_BY  varchar
    , COL_BZ  varchar
    , COL_CA  varchar
    , COL_CB  varchar
    , COL_CC  varchar
    , COL_CD  varchar
    , COL_CE  varchar
    , COL_CF  varchar
    , COL_CG  varchar
    , COL_CH  varchar
    , COL_CI  varchar
    , COL_CJ  varchar
    , COL_CK  varchar
    , COL_CL  varchar
    , COL_CM  varchar
    , COL_CN  varchar -- 2T 2026
    , COL_CO  varchar -- variación trimestral (se descarta en dbt)
    , COL_CP  varchar -- variación interanual (se descarta en dbt)
    , _fichero varchar
    , _fila    number
    , _loaded_at timestamp_ltz default current_timestamp()
)
comment = 'Raw MIVAU tabla 1 (número de transacciones de suelo urbano). Hoja completa; columnas por letra de Excel';

-- INE · tabla 50918: IPC provincial por grupos ECOICOP, base 2021 (50918.csv).
-- Cabecera del fichero: Provincias;Grupos ECOICOP;Tipo de dato;Periodo;Total
create table if not exists INE.IPC_PROVINCIAL (
      PROVINCIAS       varchar   -- '01 Araba/Álava' … '52 Melilla' y 'Nacional'
    , GRUPOS_ECOICOP   varchar   -- 'Índice general' y '01 …' a '12 …'
    , TIPO_DE_DATO     varchar   -- 'Índice' y 3 tipos de variación
    , PERIODO          varchar   -- '2002M01' … '2025M12'
    , TOTAL            varchar   -- valor con coma decimal ('119,942')
    , _fichero varchar
    , _fila    number
    , _loaded_at timestamp_ltz default current_timestamp()
)
comment = 'Raw INE tabla 50918 (IPC provincial, índices y variaciones por grupo ECOICOP, base 2021)';

-- INE · tabla 6150: compraventa de viviendas por régimen y estado (6150.csv).
-- Cabecera: Total Nacional;Comunidades y Ciudades Autónomas;Provincias;Régimen y estado;Periodo;Total
create table if not exists INE.COMPRAVENTA_VIVIENDAS (
      TOTAL_NACIONAL                    varchar   -- 'Total Nacional'
    , COMUNIDADES_Y_CIUDADES_AUTONOMAS  varchar   -- vacía en la fila nacional
    , PROVINCIAS                        varchar   -- vacía en las filas nacional y de CCAA
    , REGIMEN_Y_ESTADO                  varchar   -- 'Viviendas: Total', 'Vivienda libre'…
    , PERIODO                           varchar   -- '2007M01' … '2026M09'
    , TOTAL                             varchar   -- entero con punto de miles ('54.548')
    , _fichero varchar
    , _fila    number
    , _loaded_at timestamp_ltz default current_timestamp()
)
comment = 'Raw INE tabla 6150 (compraventa de viviendas según régimen y estado, mensual, por provincias)';

-- =================================== CARGA ===================================
-- Cada llamada indica la tabla con su nombre completo (DATABASE.ESQUEMA.TABLA) y
-- devuelve 'OK · tabla · filas · fichero' o 'ERROR · tabla · motivo'
call PRO_BRONZE_DB.UTILS.SP_CARGAR_BRONZE('PRO_BRONZE_DB.MIVAU.PRECIO_SUELO',        '36400500.csv');
call PRO_BRONZE_DB.UTILS.SP_CARGAR_BRONZE('PRO_BRONZE_DB.MIVAU.TRANSACCIONES_SUELO', '36100500.csv');
call PRO_BRONZE_DB.UTILS.SP_CARGAR_BRONZE('PRO_BRONZE_DB.INE.IPC_PROVINCIAL',        '50918.csv');
call PRO_BRONZE_DB.UTILS.SP_CARGAR_BRONZE('PRO_BRONZE_DB.INE.COMPRAVENTA_VIVIENDAS', '6150.csv');

-- =============================== COMPROBACIÓN ================================
-- Últimas 4 cargas registradas: estado OK y base_datos = PRO_BRONZE_DB
select id_carga, base_datos, tabla, fichero, filas_cargadas, estado, mensaje, fin
from PRO_BRONZE_DB.UTILS.AUDITORIA_CARGAS
order by fin desc
limit 4;

-- Filas por tabla frente a las esperadas según el perfilado de los ficheros
select 'MIVAU.PRECIO_SUELO' as tabla, count(*) as filas, 83 as filas_esperadas
from PRO_BRONZE_DB.MIVAU.PRECIO_SUELO
union all
select 'MIVAU.TRANSACCIONES_SUELO', count(*), 85
from PRO_BRONZE_DB.MIVAU.TRANSACCIONES_SUELO
union all
select 'INE.IPC_PROVINCIAL', count(*), 793728
from PRO_BRONZE_DB.INE.IPC_PROVINCIAL
union all
select 'INE.COMPRAVENTA_VIVIENDAS', count(*), 85320
from PRO_BRONZE_DB.INE.COMPRAVENTA_VIVIENDAS
order by tabla;
