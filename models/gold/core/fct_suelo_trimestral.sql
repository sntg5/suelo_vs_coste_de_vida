-- =============================================================================
-- fct_suelo_trimestral
-- =============================================================================
-- Hecho de foto periódica: una fila por provincia y trimestre (1.600 filas).
-- Se une a dim_tiempo por el primer mes del trimestre (202004 = 2T 2020) y a
-- dim_lugar por sk_lugar, calculada con la misma función que la dimensión.
-- Medidas:
-- - precio_m2: no aditiva (es una media). Para agregar se usan
--   precio_x_transacciones / transacciones_con_precio, que valen 0 en los
--   trimestres sin precio para no sesgar la media.
-- - ipc_trimestral: media de los 3 meses del Índice general de la provincia.
-- - precio_hipotetico: precio que tendría el suelo si desde el año base
--   hubiera subido como el IPC de su provincia:
--   precio_base × ipc_trimestral / ipc_medio_base.
-- - hipotetico_x_transacciones: numerador del hipotético ponderado, con los
--   mismos pesos que el precio real.
-- - variacion_interanual: frente al mismo trimestre del año anterior (NULL en
--   el primer año del periodo).
-- - es_fiable: FALSE con menos de umbral_fiabilidad compraventas.
-- =============================================================================

WITH suelo AS (

    SELECT
        suelo.id_provincia,
        suelo.id_trimestre,
        trimestres.anio,
        suelo.precio_m2,
        suelo.num_transacciones,
        IFF(suelo.precio_m2 IS NULL, 0, suelo.num_transacciones) AS transacciones_con_precio,
        COALESCE(suelo.precio_m2 * suelo.num_transacciones, 0) AS precio_x_transacciones
    FROM {{ ref('slv_suelo_trimestral') }} AS suelo
    INNER JOIN {{ ref('slv_trimestre') }} AS trimestres
        ON trimestres.id_trimestre = suelo.id_trimestre

),

primer_mes AS (

    SELECT
        id_trimestre,
        MIN(id_mes) AS id_mes
    FROM {{ ref('slv_mes') }}
    GROUP BY id_trimestre

),

ipc_trimestral AS (

    SELECT
        ipc.id_provincia,
        meses.id_trimestre,
        AVG(ipc.indice) AS ipc_trimestral
    FROM {{ ref('slv_ipc_mensual') }} AS ipc
    INNER JOIN {{ ref('slv_mes') }} AS meses
        ON meses.id_mes = ipc.id_mes
    WHERE ipc.id_grupo = '00'
    GROUP BY
        ipc.id_provincia,
        meses.id_trimestre

),

valores_base AS (

    SELECT
        suelo.id_provincia,
        {{ media_ponderada('suelo.precio_x_transacciones', 'suelo.transacciones_con_precio') }} AS precio_base,
        AVG(ipc_trimestral.ipc_trimestral) AS ipc_medio_base
    FROM suelo
    INNER JOIN ipc_trimestral
        ON ipc_trimestral.id_provincia = suelo.id_provincia
        AND ipc_trimestral.id_trimestre = suelo.id_trimestre
    WHERE suelo.anio = {{ var('anio_base') }}
    GROUP BY suelo.id_provincia

),

calculos AS (

    SELECT
        suelo.id_provincia,
        suelo.id_trimestre,
        suelo.precio_m2,
        suelo.num_transacciones,
        suelo.transacciones_con_precio,
        suelo.precio_x_transacciones,
        ipc_trimestral.ipc_trimestral,
        {{ precio_hipotetico('valores_base.precio_base', 'ipc_trimestral.ipc_trimestral', 'valores_base.ipc_medio_base') }} AS precio_hipotetico,
        LAG(suelo.precio_m2, 4) OVER (
            PARTITION BY suelo.id_provincia
            ORDER BY suelo.id_trimestre
        ) AS precio_m2_anio_anterior,
        suelo.num_transacciones >= {{ var('umbral_fiabilidad') }} AS es_fiable
    FROM suelo
    INNER JOIN ipc_trimestral
        ON ipc_trimestral.id_provincia = suelo.id_provincia
        AND ipc_trimestral.id_trimestre = suelo.id_trimestre
    INNER JOIN valores_base
        ON valores_base.id_provincia = suelo.id_provincia

)

SELECT
    CAST({{ dbt_utils.generate_surrogate_key(['calculos.id_provincia']) }} AS VARCHAR(32)) AS sk_lugar,
    CAST(primer_mes.id_mes AS NUMBER(6, 0)) AS id_mes,
    CAST(calculos.precio_m2 AS NUMBER(8, 2)) AS precio_m2,
    CAST(calculos.num_transacciones AS NUMBER(9, 0)) AS num_transacciones,
    CAST(calculos.transacciones_con_precio AS NUMBER(9, 0)) AS transacciones_con_precio,
    CAST(calculos.precio_x_transacciones AS NUMBER(14, 2)) AS precio_x_transacciones,
    CAST(calculos.ipc_trimestral AS NUMBER(10, 4)) AS ipc_trimestral,
    CAST(calculos.precio_hipotetico AS NUMBER(10, 2)) AS precio_hipotetico,
    CAST(calculos.precio_hipotetico * calculos.transacciones_con_precio AS NUMBER(14, 2)) AS hipotetico_x_transacciones,
    CAST(calculos.precio_m2 - calculos.precio_hipotetico AS NUMBER(10, 2)) AS diferencia,
    CAST({{ variacion_pct('calculos.precio_m2', 'calculos.precio_m2_anio_anterior') }} AS NUMBER(9, 4)) AS variacion_interanual,
    CAST(calculos.es_fiable AS BOOLEAN) AS es_fiable
FROM calculos
INNER JOIN primer_mes
    ON primer_mes.id_trimestre = calculos.id_trimestre