-- =============================================================================
-- slv_etapa
-- =============================================================================
-- Una fila por etapa del periodo respecto a la pandemia. Los años de cada
-- etapa no se guardan aquí: se expresan con la clave slv_anio.id_etapa.
-- orden_etapa sirve para ordenar las etapas en los gráficos.
-- =============================================================================

WITH etapas AS (

    SELECT
        id_etapa,
        nombre_etapa,
        descripcion,
        orden_etapa
    FROM {{ ref('seed_etapas') }}

)

SELECT
    CAST(id_etapa AS VARCHAR(3)) AS id_etapa,
    CAST(nombre_etapa AS VARCHAR(30)) AS nombre_etapa,
    CAST(descripcion AS VARCHAR(200)) AS descripcion,
    CAST(orden_etapa AS NUMBER(1, 0)) AS orden_etapa
FROM etapas