-- =============================================================================
-- slv_compraventa_vivienda_mensual
-- =============================================================================
-- Una fila por provincia, mes y tipo de vivienda: compraventas de viviendas
-- inscritas (INE tabla 6150). Los últimos meses que publica el INE son
-- provisionales y se revisan: el snapshot snp_compraventa_vivienda guarda
-- cada versión que cambia.
-- Las filas salen de provincias × meses × tipos, no de los datos, hasta el
-- último mes que ha publicado el INE: si le faltara un dato dentro de ese
-- periodo, la fila existiría con num_compraventas NULL y los tests lo
-- detectarían. Los meses que el INE todavía no ha publicado no se crean.
-- 2FN: aquí solo quedan claves y la medida.
-- El total de viviendas no se guarda: es libre + protegida (o nueva + usada)
-- y lo calcula Gold.
-- Incremental con estrategia merge y clave provincia, mes y tipo:
-- - La primera vez (o con --full-refresh) se construye la tabla entera.
-- - En las demás ejecuciones solo se procesan los meses de la ventana de
--   revisión (macro ventana_revision): del último mes cargado menos
--   meses_revision en adelante. Merge actualiza las filas de esos meses que
--   ya existen (las correcciones del INE) e inserta las que no existen (los
--   meses nuevos). Los meses anteriores a la ventana no se tocan.
-- - on_schema_change='append_new_columns': si se añade una columna, dbt la
--   crea en la tabla sin fallar; las filas anteriores a la ventana quedan con
--   NULL hasta ejecutar con --full-refresh.
-- =============================================================================

{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['id_provincia', 'id_mes', 'id_tipo_vivienda'],
        on_schema_change='append_new_columns'
    )
}}

WITH compraventas AS (

    SELECT
        id_provincia,
        id_mes,
        id_tipo_vivienda,
        num_compraventas
    FROM {{ ref('int_ine__compraventa_vivienda_1fn') }}

),

provincias AS (

    SELECT
        id_provincia
    FROM {{ ref('slv_provincia') }}

),

meses AS (

    SELECT
        id_mes
    FROM {{ ref('slv_mes') }}
    WHERE id_mes <= (
        SELECT
            MAX(id_mes)
        FROM compraventas
    )
    {%- if is_incremental() %}
        AND id_mes >= {{ ventana_revision(this) }}
    {%- endif %}

),

tipos AS (

    SELECT
        id_tipo_vivienda
    FROM {{ ref('slv_tipo_vivienda') }}

)

SELECT
    CAST(provincias.id_provincia AS VARCHAR(2)) AS id_provincia,
    CAST(meses.id_mes AS NUMBER(6, 0)) AS id_mes,
    CAST(tipos.id_tipo_vivienda AS VARCHAR(10)) AS id_tipo_vivienda,
    CAST(compraventas.num_compraventas AS NUMBER(9, 0)) AS num_compraventas
FROM provincias
CROSS JOIN meses
CROSS JOIN tipos
LEFT JOIN compraventas
    ON compraventas.id_provincia = provincias.id_provincia
    AND compraventas.id_mes = meses.id_mes
    AND compraventas.id_tipo_vivienda = tipos.id_tipo_vivienda