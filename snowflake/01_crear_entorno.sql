-- =============================================================================
-- 01 · Entorno Snowflake del proyecto (DEV y PRO)
-- =============================================================================
-- Proyecto: precio del suelo urbano frente al IPC en España (2018-2025).
-- Crea el warehouse, las databases, los roles y sus permisos:
--   · Dos entornos: DEV y PRO.
--   · Bronze se crea solo en PRO, que es donde se cargan los datos.
--     DEV_BRONZE_DB es un clon de PRO (04_clonar_bronze.sql).
--   · Esquemas de Bronze: MIVAU e INE (uno por organismo de origen) y UTILS
--     (utilidades de carga).
--   · El usuario se obtiene con current_user(), así no queda escrito en el script.
-- Se puede ejecutar varias veces sin error ("if not exists").
-- =============================================================================

-- Usuario actual en una variable de sesión (se usa en los grants)
set usuario = current_user();

-- Sesiones sin roles secundarios. Por defecto Snowflake activa como
-- secundarios todos los roles del usuario (DEFAULT_SECONDARY_ROLES = ('ALL')),
-- y una sesión con DEV_TRANSFORM_ROLE podría leer PRO con los privilegios de
-- otro rol. Con () cada sesión trabaja solo con su rol principal, y la
-- separación entre DEV y PRO se cumple también en dbt y en Power BI.
alter user identifier($usuario) set default_secondary_roles = ();

-- 1. Warehouse: el más pequeño, con suspensión automática a los 60 s para no
--    gastar créditos mientras no se usa.
use role sysadmin;
create warehouse if not exists WH_CURSO
    warehouse_size = 'XSMALL'
    auto_suspend = 60
    auto_resume = true
    initially_suspended = true
    comment = 'Warehouse del proyecto final: XS y suspensión a los 60 s';

-- 2. Databases (5). La sexta, DEV_BRONZE_DB, la crea el clon.
create database if not exists PRO_BRONZE_DB
    comment = 'Bronze PRO: datos crudos de las 4 fuentes. DEV_BRONZE_DB es un clon';
create schema if not exists PRO_BRONZE_DB.MIVAU
    comment = 'Ministerio de Vivienda: precio (tabla 4) y transacciones (tabla 1) de suelo urbano';
create schema if not exists PRO_BRONZE_DB.INE
    comment = 'INE: IPC provincial (tabla 50918) y compraventa de viviendas (tabla 6150)';
create schema if not exists PRO_BRONZE_DB.UTILS
    comment = 'Stage, file formats, funciones, procedimiento de carga y auditoría';

create database if not exists DEV_SILVER_DB comment = 'Silver DEV: staging, intermedios, slv_, seeds y snapshot';
create database if not exists DEV_GOLD_DB   comment = 'Gold DEV: estrella (core) y marts';
create database if not exists PRO_SILVER_DB comment = 'Silver PRO: staging, intermedios, slv_, seeds y snapshot';
create database if not exists PRO_GOLD_DB   comment = 'Gold PRO: estrella (core) y marts. La lee Power BI';

-- 3. Roles: uno de transformación por entorno y uno de lectura para Power BI.
--    dbt usa el rol de su entorno; el de DEV no puede escribir en PRO.
use role securityadmin;
create role if not exists DEV_TRANSFORM_ROLE comment = 'dbt en DEV (IDE y job DEV)';
create role if not exists PRO_TRANSFORM_ROLE comment = 'dbt en PRO (job PRO)';
create role if not exists REPORTING_ROLE     comment = 'Lectura de Gold PRO para Power BI';

-- Los roles nuevos dependen de SYSADMIN, que así puede gestionar lo que creen
grant role DEV_TRANSFORM_ROLE to role sysadmin;
grant role PRO_TRANSFORM_ROLE to role sysadmin;
grant role REPORTING_ROLE     to role sysadmin;

-- El usuario del proyecto actúa como desarrollador, como usuario de los jobs y
-- como usuario de Power BI. En un proyecto real habría usuarios de servicio.
grant role DEV_TRANSFORM_ROLE to user identifier($usuario);
grant role PRO_TRANSFORM_ROLE to user identifier($usuario);
grant role REPORTING_ROLE     to user identifier($usuario);

-- 4. Warehouse para los tres roles (Power BI también ejecuta consultas al importar)
grant usage on warehouse WH_CURSO to role DEV_TRANSFORM_ROLE;
grant usage on warehouse WH_CURSO to role PRO_TRANSFORM_ROLE;
grant usage on warehouse WH_CURSO to role REPORTING_ROLE;

-- 5. Cada rol de transformación crea esquemas solo en Silver y Gold de su
--    entorno. Quien crea un esquema es su propietario: dbt puede crear y
--    reemplazar tablas y vistas dentro sin más permisos.
grant usage, create schema on database DEV_SILVER_DB to role DEV_TRANSFORM_ROLE;
grant usage, create schema on database DEV_GOLD_DB   to role DEV_TRANSFORM_ROLE;
grant usage, create schema on database PRO_SILVER_DB to role PRO_TRANSFORM_ROLE;
grant usage, create schema on database PRO_GOLD_DB   to role PRO_TRANSFORM_ROLE;

-- REPORTING_ROLE entra en la database de Gold PRO. La lectura de los esquemas
-- core y marts la concede la macro grant_select_on_gold de dbt.
grant usage on database PRO_GOLD_DB to role REPORTING_ROLE;

-- La lectura de Bronze se concede en 04_clonar_bronze.sql, cuando ya existen
-- las tablas.

-- Comprobación: aparecen las 5 databases del proyecto y SNOWFLAKE_LEARNING_DB,
-- que es de Snowflake.
use role sysadmin;
show databases like '%_DB';
