-- =============================================================================
-- dim_tiempo
-- =============================================================================
-- Dimensión de tiempo a grano mes: una fila por mes del periodo (96), con
-- toda su jerarquía en la misma tabla (etapa → año → trimestre → mes). Es la
-- versión desnormalizada de slv_mes, slv_trimestre, slv_anio y slv_etapa.
-- La clave es id_mes (AAAAMM): estable, legible y ordena bien, así que no
-- necesita clave subrogada. fecha_inicio_mes es el mismo mes en tipo fecha,
-- para el eje de tiempo de Power BI. La comparten los 3 hechos.
-- =============================================================================

WITH meses AS (

    SELECT
        meses.id_mes,
        meses.num_mes,
        trimestres.id_trimestre,
        trimestres.num_trimestre,
        anios.anio,
        etapas.id_etapa,
        etapas.nombre_etapa,
        etapas.orden_etapa
    FROM {{ ref('slv_mes') }} AS meses
    INNER JOIN {{ ref('slv_trimestre') }} AS trimestres
        ON trimestres.id_trimestre = meses.id_trimestre
    INNER JOIN {{ ref('slv_anio') }} AS anios
        ON anios.anio = trimestres.anio
    INNER JOIN {{ ref('slv_etapa') }} AS etapas
        ON etapas.id_etapa = anios.id_etapa

)

SELECT
    CAST(id_mes AS NUMBER(6, 0)) AS id_mes,
    DATE_FROM_PARTS(anio, num_mes, 1) AS fecha_inicio_mes,
    CAST(num_mes AS NUMBER(2, 0)) AS num_mes,
    CAST(id_trimestre AS NUMBER(5, 0)) AS id_trimestre,
    CAST(num_trimestre AS NUMBER(1, 0)) AS num_trimestre,
    CAST(TO_VARCHAR(anio) || '-T' || TO_VARCHAR(num_trimestre) AS VARCHAR(7)) AS etiqueta_trimestre,
    CAST(anio AS NUMBER(4, 0)) AS anio,
    CAST(id_etapa AS VARCHAR(3)) AS id_etapa,
    CAST(nombre_etapa AS VARCHAR(30)) AS etapa,
    CAST(orden_etapa AS NUMBER(1, 0)) AS orden_etapa
FROM meses