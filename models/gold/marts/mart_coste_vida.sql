-- =============================================================================
-- mart_coste_vida
-- =============================================================================
-- Data Mart del caso 4: ¿dónde y en qué ha subido más el coste de vida?
-- Una fila por provincia, grupo de gasto y año: 50 × 13 × 8 = 5.200 filas.
-- Solo nivel provincia: el IPC no se agrega a CCAA, zona ni España porque el
-- INE no publica las ponderaciones de cada provincia. La cifra de España se
-- cita como referencia con el IPC Nacional del INE.
-- - nombre_grupo_corto: rótulo corto del grupo, el mismo de dim_grupo_ipc.
-- - ipc_medio_anual: media de los 12 índices mensuales del año.
-- - variacion_vs_2018: subida acumulada frente al año base.
-- - variacion_interanual: frente al año anterior (NULL en el primer año).
-- - ranking_provincias: posición de la provincia en la subida acumulada
--   frente al año base, por grupo y año (1 = la que más sube). NULL en el año
--   base, donde todas las variaciones son 0.
-- =============================================================================

WITH base AS (

    SELECT
        lugar.id_provincia,
        lugar.provincia,
        lugar.id_ccaa,
        lugar.ccaa,
        lugar.zona,
        grupos.id_grupo,
        grupos.nombre_grupo,
        grupos.nombre_grupo_corto,
        grupos.es_indice_general,
        grupos.es_grupo_vivienda,
        tiempo.anio,
        ipc.indice
    FROM {{ ref('fct_ipc_mensual') }} AS ipc
    INNER JOIN {{ ref('dim_lugar') }} AS lugar
        ON lugar.sk_lugar = ipc.sk_lugar
    INNER JOIN {{ ref('dim_grupo_ipc') }} AS grupos
        ON grupos.sk_grupo_ipc = ipc.sk_grupo_ipc
    INNER JOIN {{ ref('dim_tiempo') }} AS tiempo
        ON tiempo.id_mes = ipc.id_mes

),

por_anio AS (

    SELECT
        id_provincia,
        provincia,
        id_ccaa,
        ccaa,
        zona,
        id_grupo,
        nombre_grupo,
        nombre_grupo_corto,
        es_indice_general,
        es_grupo_vivienda,
        anio,
        AVG(indice) AS ipc_medio_anual
    FROM base
    GROUP BY
        id_provincia,
        provincia,
        id_ccaa,
        ccaa,
        zona,
        id_grupo,
        nombre_grupo,
        nombre_grupo_corto,
        es_indice_general,
        es_grupo_vivienda,
        anio

),

con_referencias AS (

    SELECT
        *,
        MAX(IFF(anio = {{ var('anio_base') }}, ipc_medio_anual, NULL)) OVER (
            PARTITION BY id_provincia, id_grupo
        ) AS ipc_medio_base,
        LAG(ipc_medio_anual) OVER (
            PARTITION BY id_provincia, id_grupo
            ORDER BY anio
        ) AS ipc_medio_anio_anterior
    FROM por_anio

),

variaciones AS (

    SELECT
        *,
        {{ variacion_pct('ipc_medio_anual', 'ipc_medio_base') }} AS variacion_vs_2018,
        {{ variacion_pct('ipc_medio_anual', 'ipc_medio_anio_anterior') }} AS variacion_interanual
    FROM con_referencias

)

SELECT
    id_provincia,
    provincia,
    id_ccaa,
    ccaa,
    zona,
    id_grupo,
    nombre_grupo,
    nombre_grupo_corto,
    es_indice_general,
    es_grupo_vivienda,
    anio,
    ipc_medio_anual,
    variacion_vs_2018,
    variacion_interanual,
    IFF(
        anio = {{ var('anio_base') }},
        NULL,
        RANK() OVER (
            PARTITION BY id_grupo, anio
            ORDER BY variacion_vs_2018 DESC
        )
    ) AS ranking_provincias
FROM variaciones