{# =============================================================================
   unpivot_trimestres(relacion, nombre_valor)
   =============================================================================
   Pasa a filas las 90 columnas de trimestres de una tabla del MIVAU (grupo
   repetitivo → 1FN). Genera una SELECT por columna, unidas con UNION ALL, y
   asigna el periodo por la posición de la columna en la lista de
   columnas_trimestres_mivau() (posición 0 = 1T 2004):
     anio          = 2004 + posición div 4
     num_trimestre = posición mod 4 + 1
   No se usa la cabecera de la hoja porque no es fiable (el 4T 2023 de la
   tabla 1 no tiene etiqueta y hay etiquetas con espacios).
   relacion debe ser un CTE del modelo que ya lea staging y quite las filas
   que no son datos: así Snowflake lee la vista de staging (con sus 90
   conversiones) una sola vez, y no una vez por cada SELECT.
   Devuelve _fila, territorio, anio, num_trimestre y el valor con el nombre
   indicado en nombre_valor.
   ============================================================================= #}
{% macro unpivot_trimestres(relacion, nombre_valor) %}

    {%- for columna in columnas_trimestres_mivau() %}
    SELECT
        _fila,
        territorio,
        {{ 2004 + loop.index0 // 4 }} AS anio,
        {{ loop.index0 % 4 + 1 }} AS num_trimestre,
        {{ columna }} AS {{ nombre_valor }}
    FROM {{ relacion }}
    {% if not loop.last %}
    UNION ALL
    {% endif %}
    {%- endfor %}

{% endmacro %}