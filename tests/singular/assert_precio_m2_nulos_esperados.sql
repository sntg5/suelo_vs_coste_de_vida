-- En el periodo hay exactamente 3 trimestres sin precio publicado ('n.s.'):
-- Ávila y Soria en el 2T 2020 y Ourense en el 2T 2024. Es un aviso.
-- Devuelve una fila si el número de precios nulos es distinto de 3.

{{ config(severity='warn') }}

SELECT
    COUNT(*) AS precios_nulos
FROM {{ ref('slv_suelo_trimestral') }}
WHERE precio_m2 IS NULL
HAVING COUNT(*) <> 3