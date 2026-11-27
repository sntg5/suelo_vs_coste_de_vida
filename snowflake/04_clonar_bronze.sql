-- =============================================================================
-- 04 · Bronze en DEV (zero-copy clone de PRO) y permisos de lectura de Bronze
-- =============================================================================
-- Los datos se cargan en PRO y DEV recibe una copia: DEV_BRONZE_DB es un clon
-- de PRO_BRONZE_DB. Un clon no duplica el almacenamiento al crearse; solo
-- ocupa espacio lo que cambie después.
-- Qué copia el clon:
--   · Tablas, funciones, procedimiento, file formats y la tabla de auditoría
--     (con el historial de PRO).
--   · Los permisos concedidos sobre los objetos de dentro (tablas, esquemas,
--     funciones), pero no los de la propia database.
--   · No copia el stage interno: sin INCLUDE INTERNAL STAGES, los stages
--     internos no se clonan. DEV tiene su propio stage CARGA_BRONZE para las
--     cargas que solo van a DEV (la entrega simulada de vivienda).
-- Volver a ejecutar el script "resetea" DEV: borra DEV_BRONZE_DB, incluida la
-- entrega simulada, y la clona de nuevo desde PRO.
-- Permisos: cada rol de transformación solo lee el Bronze de su entorno. La
-- carga de Bronze la hace siempre SYSADMIN, así que ningún rol de
-- transformación tiene USAGE sobre SP_CARGAR_BRONZE.
-- =============================================================================

use role sysadmin;
use warehouse WH_CURSO;

-- 1. Clon de PRO a DEV
create or replace database DEV_BRONZE_DB clone PRO_BRONZE_DB
    comment = 'Bronze DEV: clon de PRO_BRONZE_DB. Aquí se carga la entrega simulada de vivienda';

-- Stages internos que ha copiado el clon (se usa en la comprobación final)
set stages_tras_clon = (select count(*) from DEV_BRONZE_DB.information_schema.stages);

-- 2. Stage propio de DEV y fichero de prueba
create stage if not exists DEV_BRONZE_DB.UTILS.CARGA_BRONZE
    comment = 'Ficheros que se cargan solo en DEV (entrega simulada y pruebas)';

-- COPY FILES copia un fichero de un stage a otro sin volver a subirlo
copy files into @DEV_BRONZE_DB.UTILS.CARGA_BRONZE
    from @PRO_BRONZE_DB.UTILS.CARGA_BRONZE
    files = ('36400500.csv');

-- 3. Permisos de lectura de Bronze
use role securityadmin;

-- PRO_TRANSFORM_ROLE lee PRO_BRONZE_DB y usa sus funciones
grant usage on database PRO_BRONZE_DB to role PRO_TRANSFORM_ROLE;
grant usage on all schemas in database PRO_BRONZE_DB to role PRO_TRANSFORM_ROLE;
grant select on all tables in database PRO_BRONZE_DB to role PRO_TRANSFORM_ROLE;
grant usage on all functions in schema PRO_BRONZE_DB.UTILS to role PRO_TRANSFORM_ROLE;

-- El clon copia los permisos de los objetos de dentro: si PRO ya tenía los
-- grants de PRO_TRANSFORM_ROLE, DEV también los tiene. Se quitan para que cada
-- rol solo vea su entorno.
revoke select on all tables in database DEV_BRONZE_DB from role PRO_TRANSFORM_ROLE;
revoke usage on all schemas in database DEV_BRONZE_DB from role PRO_TRANSFORM_ROLE;
revoke usage on all functions in schema DEV_BRONZE_DB.UTILS from role PRO_TRANSFORM_ROLE;

-- DEV_TRANSFORM_ROLE lee DEV_BRONZE_DB y usa sus funciones
grant usage on database DEV_BRONZE_DB to role DEV_TRANSFORM_ROLE;
grant usage on all schemas in database DEV_BRONZE_DB to role DEV_TRANSFORM_ROLE;
grant select on all tables in database DEV_BRONZE_DB to role DEV_TRANSFORM_ROLE;
grant usage on all functions in schema DEV_BRONZE_DB.UTILS to role DEV_TRANSFORM_ROLE;

-- 4. Prueba del procedimiento en DEV: recarga la tabla pequeña en DEV.
--    La sesión está en PRO_BRONZE_DB a propósito: así se comprueba que la carga
--    va a la database indicada en la llamada y no a la de la sesión.
use role sysadmin;
use database PRO_BRONZE_DB;
call DEV_BRONZE_DB.UTILS.SP_CARGAR_BRONZE('DEV_BRONZE_DB.MIVAU.PRECIO_SUELO', '36400500.csv');

-- ============================== COMPROBACIONES ===============================
-- Comprobación 1: clon, stage y procedimiento de DEV. Esperado: 5 filas con ok = TRUE.
with ultima_carga_dev as (
    select base_datos, estado, filas_cargadas
    from DEV_BRONZE_DB.UTILS.AUDITORIA_CARGAS
    order by fin desc
    limit 1
),
comprobaciones as (
    select 'Stages internos copiados por el clon' as comprobacion,
           $stages_tras_clon::varchar as resultado, '0' as esperado
    union all
    select 'Tablas en DEV_BRONZE_DB (4 raw + auditoría)',
           count(*)::varchar, '5'
    from DEV_BRONZE_DB.information_schema.tables
    where table_schema in ('MIVAU', 'INE', 'UTILS')
    union all
    select 'Última carga de DEV: database', base_datos, 'DEV_BRONZE_DB'
    from ultima_carga_dev
    union all
    select 'Última carga de DEV: estado y filas', estado || ' · ' || filas_cargadas, 'OK · 83'
    from ultima_carga_dev
    union all
    select 'PRECIO_SUELO de PRO sin recargar (su carga es anterior a la de DEV)',
           iff((select max(_loaded_at) from PRO_BRONZE_DB.MIVAU.PRECIO_SUELO)
             < (select max(_loaded_at) from DEV_BRONZE_DB.MIVAU.PRECIO_SUELO), 'sí', 'no'),
           'sí'
)
select comprobacion, resultado, esperado, resultado = esperado as ok
from comprobaciones;

-- Comprobaciones 2 a 4 solo con el rol principal: sin roles secundarios, los
-- privilegios de otros roles del usuario no cuentan.
use secondary roles none;

-- Comprobación 2: PRO_TRANSFORM_ROLE lee Bronze de PRO y usa su función.
-- Esperado: 793728 y 159.7
use role PRO_TRANSFORM_ROLE;
select count(*)                                    as filas_ipc_pro,
       PRO_BRONZE_DB.UTILS.FN_TEXTO_A_NUMERO('159,7') as prueba_funcion
from PRO_BRONZE_DB.INE.IPC_PROVINCIAL;

-- Comprobación 3: DEV_TRANSFORM_ROLE lee Bronze de DEV y usa su función.
-- Esperado: 793728 y 159.7
use role DEV_TRANSFORM_ROLE;
select count(*)                                    as filas_ipc_dev,
       DEV_BRONZE_DB.UTILS.FN_TEXTO_A_NUMERO('159,7') as prueba_funcion
from DEV_BRONZE_DB.INE.IPC_PROVINCIAL;

-- Comprobación 4: databases que ve DEV_TRANSFORM_ROLE.
-- Esperado: DEV_BRONZE_DB, DEV_SILVER_DB y DEV_GOLD_DB (más las que Snowflake
-- comparte con todos los roles). No aparece ninguna PRO_*.
show databases;
