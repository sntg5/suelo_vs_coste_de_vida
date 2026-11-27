-- =============================================================================
-- cesta_fija_2018
-- =============================================================================
-- Análisis: comprobación del efecto composición del caso 1 (España).
-- En mart_suelo_vs_ipc, la media de España pondera cada año con las
-- compraventas de suelo de ese año, y cada año cambia dónde se vende el suelo.
-- Aquí se calcula la misma comparación con una cesta fija: los pesos de cada
-- provincia son sus transacciones con precio del año base y no cambian, como
-- hace el INE con el IPC.
-- - variacion_precio_cesta_fija y variacion_coste_vida_cesta_fija: subida
--   frente al año base con los pesos fijos.
-- - variacion_real_cesta_fija frente a variacion_real_mart: si las dos dan lo
--   mismo, la conclusión del caso 1 no depende de la ponderación.
-- Usa las mismas macros que los marts. No es un modelo: se abre en Studio y
-- se ejecuta con Preview.
-- =============================================================================

WITH provincias AS (

    SELECT
        id_territorio AS id_provincia,
        anio,
        precio_medio,
        precio_hipotetico,
        transacciones_con_precio
    FROM {{ ref('mart_suelo_vs_ipc') }}
    WHERE nivel = 'Provincia'

),

pesos_base AS (

    SELECT
        id_provincia,
        transacciones_con_precio AS peso_base
    FROM provincias
    WHERE anio = {{ var('anio_base') }}

),

cesta_fija AS (

    SELECT
        provincias.anio,
        {{ media_ponderada('provincias.precio_medio * pesos_base.peso_base', 'pesos_base.peso_base') }} AS precio_cesta_fija,
        {{ media_ponderada('provincias.precio_hipotetico * pesos_base.peso_base', 'pesos_base.peso_base') }} AS hipotetico_cesta_fija
    FROM provincias
    INNER JOIN pesos_base
        ON pesos_base.id_provincia = provincias.id_provincia
    GROUP BY provincias.anio

),

con_base AS (

    SELECT
        *,
        MAX(IFF(anio = {{ var('anio_base') }}, precio_cesta_fija, NULL)) OVER () AS precio_cesta_fija_base,
        MAX(IFF(anio = {{ var('anio_base') }}, hipotetico_cesta_fija, NULL)) OVER () AS hipotetico_cesta_fija_base
    FROM cesta_fija

),

variaciones AS (

    SELECT
        anio,
        {{ variacion_pct('precio_cesta_fija', 'precio_cesta_fija_base') }} AS variacion_precio_cesta_fija,
        {{ variacion_pct('hipotetico_cesta_fija', 'hipotetico_cesta_fija_base') }} AS variacion_coste_vida_cesta_fija
    FROM con_base

),

espana_mart AS (

    SELECT
        anio,
        variacion_precio_vs_2018 AS variacion_precio_mart,
        variacion_ipc_vs_2018 AS variacion_coste_vida_mart,
        variacion_real_vs_2018 AS variacion_real_mart
    FROM {{ ref('mart_suelo_vs_ipc') }}
    WHERE nivel = 'España'

)

SELECT
    variaciones.anio,
    ROUND(variaciones.variacion_precio_cesta_fija * 100, 1) AS precio_cesta_fija_pct,
    ROUND(variaciones.variacion_coste_vida_cesta_fija * 100, 1) AS coste_vida_cesta_fija_pct,
    ROUND({{ variacion_real('variaciones.variacion_precio_cesta_fija', 'variaciones.variacion_coste_vida_cesta_fija') }} * 100, 1) AS variacion_real_cesta_fija_pct,
    ROUND(espana_mart.variacion_precio_mart * 100, 1) AS precio_mart_pct,
    ROUND(espana_mart.variacion_coste_vida_mart * 100, 1) AS coste_vida_mart_pct,
    ROUND(espana_mart.variacion_real_mart * 100, 1) AS variacion_real_mart_pct
FROM variaciones
INNER JOIN espana_mart
    ON espana_mart.anio = variaciones.anio
ORDER BY variaciones.anio