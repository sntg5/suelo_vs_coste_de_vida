-- =============================================================================
-- fct_compraventa_vivienda_mensual
-- =============================================================================
-- Hecho de foto periódica: una fila por provincia y mes (50 × 96 = 4.800
-- filas). Alimenta los casos 2 (pandemia) y 3 (mapa del mercado).
-- Se une a dim_lugar por sk_lugar, calculada con la misma función que la
-- dimensión, y a dim_tiempo por id_mes.
-- Los 4 tipos de vivienda pasan de filas a columnas con un bucle Jinja sobre
-- sus códigos: cada código genera su columna num_<código>. El tipo de vivienda
-- no es una dimensión porque sus dos criterios (régimen y estado) reparten el
-- mismo total: como dimensión, sumar todos los tipos daría el doble.
-- Medidas (todas aditivas salvo la variación):
-- - num_libre, num_protegida, num_nueva, num_usada: compraventas por tipo.
-- - num_total: libre + protegida (el total que Silver no guarda). Un test
--   comprueba que también es nueva + usada.
-- - variacion_interanual_total: frente al mismo mes del año anterior (NULL en
--   el primer año del periodo). No aditiva.
-- Incremental con estrategia delete+insert y clave sk_lugar e id_mes (el
-- grano):
-- - La primera vez (o con --full-refresh) se construye la tabla entera.
-- - En las demás ejecuciones se recalculan enteros los meses de la ventana de
--   revisión (macro ventana_revision): delete+insert borra las filas de esos
--   meses que ya existen y vuelve a escribirlas, junto con las de los meses
--   nuevos. Los meses anteriores a la ventana no se tocan.
-- - La variación interanual se calcula con toda la historia de Silver y la
--   ventana se filtra al final: si se filtrara antes, el LAG del primer año
--   de la ventana no encontraría el mes del año anterior y saldría NULL.
-- - on_schema_change='append_new_columns': si se añade una columna, dbt la
--   crea en la tabla sin fallar; las filas anteriores a la ventana quedan con
--   NULL hasta ejecutar con --full-refresh.
-- =============================================================================

{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['sk_lugar', 'id_mes'],
        on_schema_change='append_new_columns'
    )
}}

{% set tipos_vivienda = ['LIBRE', 'PROTEGIDA', 'NUEVA', 'USADA'] %}

WITH compraventas AS (

    SELECT
        id_provincia,
        id_mes,
        {%- for tipo in tipos_vivienda %}
        SUM(IFF(id_tipo_vivienda = '{{ tipo }}', num_compraventas, 0)) AS num_{{ tipo | lower }}{{ ',' if not loop.last }}
        {%- endfor %}
    FROM {{ ref('slv_compraventa_vivienda_mensual') }}
    GROUP BY
        id_provincia,
        id_mes

),

calculos AS (

    SELECT
        *,
        num_libre + num_protegida AS num_total,
        LAG(num_libre + num_protegida, 12) OVER (
            PARTITION BY id_provincia
            ORDER BY id_mes
        ) AS num_total_anio_anterior
    FROM compraventas

)

SELECT
    CAST({{ dbt_utils.generate_surrogate_key(['id_provincia']) }} AS VARCHAR(32)) AS sk_lugar,
    CAST(id_mes AS NUMBER(6, 0)) AS id_mes,
    CAST(num_libre AS NUMBER(9, 0)) AS num_libre,
    CAST(num_protegida AS NUMBER(9, 0)) AS num_protegida,
    CAST(num_nueva AS NUMBER(9, 0)) AS num_nueva,
    CAST(num_usada AS NUMBER(9, 0)) AS num_usada,
    CAST(num_total AS NUMBER(9, 0)) AS num_total,
    CAST({{ variacion_pct('num_total', 'num_total_anio_anterior') }} AS NUMBER(9, 4)) AS variacion_interanual_total
FROM calculos
{%- if is_incremental() %}
WHERE id_mes >= {{ ventana_revision(this) }}
{%- endif %}