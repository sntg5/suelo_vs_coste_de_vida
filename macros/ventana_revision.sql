{# =============================================================================
   ventana_revision(tabla)
   =============================================================================
   Primer mes (AAAAMM) de la ventana de revisión (lookback) de los modelos
   incrementales de vivienda: el último mes cargado en la tabla menos
   meses_revision meses (variable de dbt_project.yml). El INE publica los
   últimos meses como provisionales y los revisa cuando difunde el mismo mes
   del año siguiente, así que en cada ejecución incremental esos meses se
   vuelven a procesar aunque ya estén cargados.
   No se filtra por fecha de carga (_loaded_at mayor que el máximo de la
   tabla): Bronze sustituye el fichero completo en cada entrega y _loaded_at
   cambia en todas las filas. Se filtra por el mes del dato, id_mes, una
   columna que existe en la tabla destino.
   - tabla: la tabla del propio modelo (this). La macro se llama dentro del
     bloque is_incremental(), cuando la tabla ya existe.
   - Devuelve una subconsulta entre paréntesis para comparar con id_mes. Con
     202512 como último mes cargado y 12 meses de revisión, devuelve 202412.
   - Cálculo: el último mes (AAAAMM) pasa a la fecha de su día 1 (202512 →
     '20251201' → 2025-12-01), DATEADD le resta los meses y TO_CHAR lo
     devuelve a AAAAMM.
   La ventana se define solo aquí y la usan slv_compraventa_vivienda_mensual y
   fct_compraventa_vivienda_mensual.
   ============================================================================= #}
{% macro ventana_revision(tabla) -%}
    (
        SELECT
            TO_NUMBER(
                TO_CHAR(
                    DATEADD(MONTH, -{{ var('meses_revision') }}, TO_DATE(TO_VARCHAR(MAX(id_mes)) || '01', 'YYYYMMDD')),
                    'YYYYMM'
                )
            )
        FROM {{ tabla }}
    )
{%- endmacro %}