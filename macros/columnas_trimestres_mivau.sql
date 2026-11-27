{# =============================================================================
   columnas_trimestres_mivau()
   =============================================================================
   Devuelve la lista de las 90 columnas de trimestres de las tablas 1 y 4 del
   MIVAU en Bronze: col_c (1T 2004) ... col_cn (2T 2026). Cada columna lleva
   el nombre de su letra de Excel; la posición en la lista (0 a 89) es la que
   da el año y el trimestre: año = 2004 + posición div 4, trimestre =
   posición mod 4 + 1.
   La letra se calcula desde su número de columna contando A = 0: C es la 2 y
   CN la 91. A partir de la 26 son dos letras (AA, AB...).
   ============================================================================= #}
{% macro columnas_trimestres_mivau() %}

    {% set letras = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' %}
    {% set columnas = [] %}

    {% for posicion in range(90) %}
        {% set num_columna = posicion + 2 %}
        {% if num_columna < 26 %}
            {% set letra = letras[num_columna] %}
        {% else %}
            {% set letra = letras[num_columna // 26 - 1] ~ letras[num_columna % 26] %}
        {% endif %}
        {% do columnas.append('col_' ~ letra | lower) %}
    {% endfor %}

    {{ return(columnas) }}

{% endmacro %}