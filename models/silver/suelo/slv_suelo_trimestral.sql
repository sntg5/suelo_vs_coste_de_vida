-- =============================================================================
-- slv_suelo_trimestral
-- =============================================================================
-- Una fila por provincia y trimestre: precio medio del m² de suelo urbano
-- (MIVAU tabla 4) y número de transacciones (MIVAU tabla 1).
-- Las filas salen de provincias × trimestres (seed y calendario), no de los
-- datos: si a una fuente le faltara un periodo, la fila existiría con la
-- medida a NULL y los tests de completitud lo detectarían.
-- precio_m2 es NULL en los 3 trimestres en que el ministerio no publica
-- precio ('n.s.'); sus transacciones sí existen.
-- =============================================================================

WITH provincias AS (

    SELECT
        id_provincia
    FROM {{ ref('slv_provincia') }}

),

trimestres AS (

    SELECT
        id_trimestre
    FROM {{ ref('slv_trimestre') }}

),

suelo AS (

    SELECT
        id_provincia,
        id_trimestre,
        precio_m2,
        num_transacciones
    FROM {{ ref('int_mivau__suelo_trimestral_1fn') }}

)

SELECT
    CAST(provincias.id_provincia AS VARCHAR(2)) AS id_provincia,
    CAST(trimestres.id_trimestre AS NUMBER(5, 0)) AS id_trimestre,
    CAST(suelo.precio_m2 AS NUMBER(8, 2)) AS precio_m2,
    CAST(suelo.num_transacciones AS NUMBER(9, 0)) AS num_transacciones
FROM provincias
CROSS JOIN trimestres
LEFT JOIN suelo
    ON suelo.id_provincia = provincias.id_provincia
    AND suelo.id_trimestre = trimestres.id_trimestre