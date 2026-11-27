-- =============================================================================
-- 03b · Prueba de idempotencia de la carga de Bronze (PRO)
-- =============================================================================
-- Repite la carga de las 4 tablas y comprueba que el resultado no cambia:
--   · mismas filas antes y después de recargar;
--   · mismo contenido: HASH_AGG calcula una huella de toda la tabla (sin
--     _loaded_at, que cambia en cada carga). No depende del orden de las filas;
--   · _loaded_at posterior: la tabla se ha recargado de verdad;
--   · en AUDITORIA_CARGAS, todas las cargas OK de cada tabla tienen las mismas
--     filas.
-- La carga es idempotente porque SP_CARGAR_BRONZE vacía la tabla (TRUNCATE)
-- antes de copiar el fichero. Se puede ejecutar tantas veces como se quiera.
-- =============================================================================

use role sysadmin;
use warehouse WH_CURSO;
use database PRO_BRONZE_DB;

-- Tabla temporal: solo existe durante la sesión
create or replace temporary table UTILS.HUELLAS (
      momento    varchar      -- 'antes' o 'despues'
    , tabla      varchar
    , filas      number
    , huella     number
    , cargado_en timestamp_ltz
);

-- 1. Huella de cada tabla antes de recargar
insert into UTILS.HUELLAS
select 'antes', 'MIVAU.PRECIO_SUELO', count(*), hash_agg(* exclude _loaded_at), max(_loaded_at) from MIVAU.PRECIO_SUELO
union all
select 'antes', 'MIVAU.TRANSACCIONES_SUELO', count(*), hash_agg(* exclude _loaded_at), max(_loaded_at) from MIVAU.TRANSACCIONES_SUELO
union all
select 'antes', 'INE.IPC_PROVINCIAL', count(*), hash_agg(* exclude _loaded_at), max(_loaded_at) from INE.IPC_PROVINCIAL
union all
select 'antes', 'INE.COMPRAVENTA_VIVIENDAS', count(*), hash_agg(* exclude _loaded_at), max(_loaded_at) from INE.COMPRAVENTA_VIVIENDAS;

-- 2. Nueva carga de las 4 tablas (las mismas llamadas que en 03_cargar_bronze.sql)
call PRO_BRONZE_DB.UTILS.SP_CARGAR_BRONZE('PRO_BRONZE_DB.MIVAU.PRECIO_SUELO',        '36400500.csv');
call PRO_BRONZE_DB.UTILS.SP_CARGAR_BRONZE('PRO_BRONZE_DB.MIVAU.TRANSACCIONES_SUELO', '36100500.csv');
call PRO_BRONZE_DB.UTILS.SP_CARGAR_BRONZE('PRO_BRONZE_DB.INE.IPC_PROVINCIAL',        '50918.csv');
call PRO_BRONZE_DB.UTILS.SP_CARGAR_BRONZE('PRO_BRONZE_DB.INE.COMPRAVENTA_VIVIENDAS', '6150.csv');

-- 3. Huella de cada tabla después de recargar
insert into UTILS.HUELLAS
select 'despues', 'MIVAU.PRECIO_SUELO', count(*), hash_agg(* exclude _loaded_at), max(_loaded_at) from MIVAU.PRECIO_SUELO
union all
select 'despues', 'MIVAU.TRANSACCIONES_SUELO', count(*), hash_agg(* exclude _loaded_at), max(_loaded_at) from MIVAU.TRANSACCIONES_SUELO
union all
select 'despues', 'INE.IPC_PROVINCIAL', count(*), hash_agg(* exclude _loaded_at), max(_loaded_at) from INE.IPC_PROVINCIAL
union all
select 'despues', 'INE.COMPRAVENTA_VIVIENDAS', count(*), hash_agg(* exclude _loaded_at), max(_loaded_at) from INE.COMPRAVENTA_VIVIENDAS;

-- 4. Comparación antes / después y resumen de la auditoría
with antes as (
    select * from UTILS.HUELLAS where momento = 'antes'
),
despues as (
    select * from UTILS.HUELLAS where momento = 'despues'
),
auditoria as (
    select tabla,
           count(*)            as cargas_ok,
           min(filas_cargadas) as filas_min,
           max(filas_cargadas) as filas_max
    from UTILS.AUDITORIA_CARGAS
    where estado = 'OK'
      and base_datos = 'PRO_BRONZE_DB'
    group by tabla
)
select a.tabla,
       a.filas                   as filas_antes,
       d.filas                   as filas_despues,
       a.huella = d.huella       as mismo_contenido,
       a.cargado_en              as cargado_antes,
       d.cargado_en              as cargado_despues,
       au.cargas_ok,
       au.filas_min = au.filas_max as auditoria_mismas_filas,
       a.filas = d.filas
         and a.huella = d.huella
         and d.cargado_en > a.cargado_en
         and au.filas_min = au.filas_max as idempotente
from antes a
join despues d    on d.tabla  = a.tabla
join auditoria au on au.tabla = a.tabla
order by a.tabla;
