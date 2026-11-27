{# =============================================================================
   separar_codigo_nombre(columna, columna_id, columna_nombre)
   =============================================================================
   Separa un campo del INE que trae código y nombre juntos ('38 Santa Cruz
   de Tenerife', '04 Vivienda, agua...') en dos columnas con valores atómicos
   (1FN). Si el campo no empieza por dos cifras y un espacio ('Nacional',
   'Índice general'), el código queda NULL y el nombre es el campo entero.
   Se usa en las provincias y los grupos del IPC y en las provincias de
   compraventa de viviendas.
   ============================================================================= #}
{% macro separar_codigo_nombre(columna, columna_id, columna_nombre) -%}
    IFF(
        REGEXP_LIKE({{ columna }}, '[0-9]{2} .+'),
        LEFT({{ columna }}, 2),
        NULL
    ) AS {{ columna_id }},
    IFF(
        REGEXP_LIKE({{ columna }}, '[0-9]{2} .+'),
        TRIM(SUBSTR({{ columna }}, 4)),
        {{ columna }}
    ) AS {{ columna_nombre }}
{%- endmacro %}