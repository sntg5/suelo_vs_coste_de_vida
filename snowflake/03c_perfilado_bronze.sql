-- =============================================================================
-- 03c · Perfilado de Bronze (PRO): comprobaciones de lectura y datos para el diseño
-- =============================================================================
-- Consultas de solo lectura sobre las tablas raw de PRO_BRONZE_DB:
--   1. Valores distintos por columna en las tablas del INE, frente al perfilado
--      de los ficheros (data/README.md, §5), y lectura de las tildes (UTF-8).
--   2. Celdas de los trimestres del ministerio (columnas C a CN): número de
--      celdas, marcadores de "sin dato", ceros y máximo de decimales. Decide el
--      tipo de precio_m2 en Silver.
--   3. Los 13 valores de "Grupos ECOICOP" del IPC (nombres de slv_grupo_ipc).
--   4. Las 19 CCAA y ciudades autónomas de la tabla 6150, con su número de
--      provincias (comprobación de los códigos de CCAA del seed).
-- =============================================================================

use role sysadmin;
use warehouse WH_CURSO;
use database PRO_BRONZE_DB;

-- 1. Valores distintos en las tablas del INE.
--    Esperado: 9 filas con ok = TRUE.
with ipc as (
    select * from INE.IPC_PROVINCIAL
),
viv as (
    select * from INE.COMPRAVENTA_VIVIENDAS
),
conteos as (
    select 'INE.IPC_PROVINCIAL' as tabla, 'PROVINCIAS' as columna, count(distinct PROVINCIAS) as distintos, 53 as esperados from ipc
    union all
    select 'INE.IPC_PROVINCIAL', 'GRUPOS_ECOICOP', count(distinct GRUPOS_ECOICOP), 13 from ipc
    union all
    select 'INE.IPC_PROVINCIAL', 'TIPO_DE_DATO', count(distinct TIPO_DE_DATO), 4 from ipc
    union all
    select 'INE.IPC_PROVINCIAL', 'PERIODO', count(distinct PERIODO), 288 from ipc
    union all
    select 'INE.COMPRAVENTA_VIVIENDAS', 'COMUNIDADES_Y_CIUDADES_AUTONOMAS', count(distinct COMUNIDADES_Y_CIUDADES_AUTONOMAS), 19 from viv
    union all
    select 'INE.COMPRAVENTA_VIVIENDAS', 'PROVINCIAS', count(distinct PROVINCIAS), 52 from viv
    union all
    select 'INE.COMPRAVENTA_VIVIENDAS', 'REGIMEN_Y_ESTADO', count(distinct REGIMEN_Y_ESTADO), 5 from viv
    union all
    select 'INE.COMPRAVENTA_VIVIENDAS', 'PERIODO', count(distinct PERIODO), 237 from viv
    union all
    -- Ávila con tilde: 14.976 filas en el IPC + 1.185 en compraventas
    select 'LAS DOS', 'filas con ''05 Ávila''',
           (select count(*) from ipc where PROVINCIAS = '05 Ávila')
         + (select count(*) from viv where PROVINCIAS = '05 Ávila'),
           16161
)
select tabla, columna, distintos, esperados, distintos = esperados as ok
from conteos
order by tabla, columna;

-- 2. Celdas de los trimestres en las tablas del ministerio (filas de datos desde
--    la fila 14 de Excel). UNPIVOT pasa las 90 columnas a filas y descarta las
--    celdas vacías.
--    Esperado: PRECIO_SUELO 5.580 celdas, 74 sin dato, 0 ceros, 2 decimales;
--              TRANSACCIONES_SUELO 5.760 celdas, 2 sin dato, 79 ceros, 0 decimales.
with celdas as (
    select 'MIVAU.PRECIO_SUELO' as tabla, valor
    from MIVAU.PRECIO_SUELO
    unpivot (valor for columna in (
            COL_C, COL_D, COL_E, COL_F, COL_G, COL_H, COL_I, COL_J, COL_K, COL_L,
            COL_M, COL_N, COL_O, COL_P, COL_Q, COL_R, COL_S, COL_T, COL_U, COL_V,
            COL_W, COL_X, COL_Y, COL_Z, COL_AA, COL_AB, COL_AC, COL_AD, COL_AE, COL_AF,
            COL_AG, COL_AH, COL_AI, COL_AJ, COL_AK, COL_AL, COL_AM, COL_AN, COL_AO, COL_AP,
            COL_AQ, COL_AR, COL_AS, COL_AT, COL_AU, COL_AV, COL_AW, COL_AX, COL_AY, COL_AZ,
            COL_BA, COL_BB, COL_BC, COL_BD, COL_BE, COL_BF, COL_BG, COL_BH, COL_BI, COL_BJ,
            COL_BK, COL_BL, COL_BM, COL_BN, COL_BO, COL_BP, COL_BQ, COL_BR, COL_BS, COL_BT,
            COL_BU, COL_BV, COL_BW, COL_BX, COL_BY, COL_BZ, COL_CA, COL_CB, COL_CC, COL_CD,
            COL_CE, COL_CF, COL_CG, COL_CH, COL_CI, COL_CJ, COL_CK, COL_CL, COL_CM, COL_CN
    ))
    where _fila >= 14 and COL_B is not null
    union all
    select 'MIVAU.TRANSACCIONES_SUELO', valor
    from MIVAU.TRANSACCIONES_SUELO
    unpivot (valor for columna in (
            COL_C, COL_D, COL_E, COL_F, COL_G, COL_H, COL_I, COL_J, COL_K, COL_L,
            COL_M, COL_N, COL_O, COL_P, COL_Q, COL_R, COL_S, COL_T, COL_U, COL_V,
            COL_W, COL_X, COL_Y, COL_Z, COL_AA, COL_AB, COL_AC, COL_AD, COL_AE, COL_AF,
            COL_AG, COL_AH, COL_AI, COL_AJ, COL_AK, COL_AL, COL_AM, COL_AN, COL_AO, COL_AP,
            COL_AQ, COL_AR, COL_AS, COL_AT, COL_AU, COL_AV, COL_AW, COL_AX, COL_AY, COL_AZ,
            COL_BA, COL_BB, COL_BC, COL_BD, COL_BE, COL_BF, COL_BG, COL_BH, COL_BI, COL_BJ,
            COL_BK, COL_BL, COL_BM, COL_BN, COL_BO, COL_BP, COL_BQ, COL_BR, COL_BS, COL_BT,
            COL_BU, COL_BV, COL_BW, COL_BX, COL_BY, COL_BZ, COL_CA, COL_CB, COL_CC, COL_CD,
            COL_CE, COL_CF, COL_CG, COL_CH, COL_CI, COL_CJ, COL_CK, COL_CL, COL_CM, COL_CN
    ))
    where _fila >= 14 and COL_B is not null
)
select tabla,
       count(*)                                 as celdas,
       count_if(valor in ('n.s.', 'n.s', '.'))  as celdas_sin_dato,
       count_if(valor = '0')                    as celdas_cero,
       max(length(split_part(valor, ',', 2)))   as max_decimales
from celdas
group by tabla
order by tabla;

-- 3. Grupos ECOICOP del IPC.
--    Esperado: 13 filas (Índice general y grupos 01 a 12), 61.056 filas cada uno.
select GRUPOS_ECOICOP, count(*) as filas
from INE.IPC_PROVINCIAL
group by GRUPOS_ECOICOP
order by GRUPOS_ECOICOP;

-- 4. CCAA y ciudades autónomas de la tabla 6150 con su número de provincias.
--    Esperado: 19 filas (01 a 17, 18 Ceuta y 19 Melilla).
select COMUNIDADES_Y_CIUDADES_AUTONOMAS as ccaa,
       count(distinct PROVINCIAS)       as provincias
from INE.COMPRAVENTA_VIVIENDAS
where COMUNIDADES_Y_CIUDADES_AUTONOMAS is not null
group by COMUNIDADES_Y_CIUDADES_AUTONOMAS
order by COMUNIDADES_Y_CIUDADES_AUTONOMAS;
