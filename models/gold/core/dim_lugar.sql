-- =============================================================================
-- dim_lugar
-- =============================================================================
-- Dimensión de lugar: una fila por provincia (50), con toda su jerarquía en
-- la misma tabla (país → zona → CCAA → provincia). Es la versión
-- desnormalizada de slv_provincia, slv_comunidad_autonoma y slv_zona: en
-- Gold la jerarquía va dentro de la dimensión (estrella, no copo de nieve).
-- sk_lugar es una clave subrogada (hash del código INE) y el código se
-- conserva como atributo. La comparten los 3 hechos (dimensión conformada).
-- =============================================================================

WITH provincias AS (

    SELECT
        provincias.id_provincia,
        provincias.nombre_provincia,
        comunidades.id_ccaa,
        comunidades.nombre_ccaa,
        zonas.id_zona,
        zonas.nombre_zona
    FROM {{ ref('slv_provincia') }} AS provincias
    INNER JOIN {{ ref('slv_comunidad_autonoma') }} AS comunidades
        ON comunidades.id_ccaa = provincias.id_ccaa
    INNER JOIN {{ ref('slv_zona') }} AS zonas
        ON zonas.id_zona = comunidades.id_zona

)

SELECT
    CAST({{ dbt_utils.generate_surrogate_key(['id_provincia']) }} AS VARCHAR(32)) AS sk_lugar,
    CAST(id_provincia AS VARCHAR(2)) AS id_provincia,
    CAST(nombre_provincia AS VARCHAR(50)) AS provincia,
    CAST(id_ccaa AS VARCHAR(2)) AS id_ccaa,
    CAST(nombre_ccaa AS VARCHAR(50)) AS ccaa,
    CAST(id_zona AS VARCHAR(3)) AS id_zona,
    CAST(nombre_zona AS VARCHAR(20)) AS zona,
    CAST('España' AS VARCHAR(10)) AS pais
FROM provincias