{# =============================================================================
   generate_schema_name(custom_schema_name, node)
   =============================================================================
   Sustituye a la macro de dbt que decide en qué esquema se crea cada objeto.
   - Jobs de los entornos de despliegue (target dev o pro): se usa el esquema
     de la carpeta tal cual (staging, silver, core...), porque cada entorno
     ya escribe en sus propias bases de datos (DEV_* o PRO_*).
   - Desarrollo en el IDE (cualquier otro target, como default): se usa
     <esquema personal>_<esquema>, para no pisar los esquemas de los jobs,
     que comparten las bases DEV_*.
   - Sin esquema personalizado: el esquema del target.
   No hay entorno PRE, por eso la lista solo tiene dev y pro.
   ============================================================================= #}
{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}

    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name | lower in ['dev', 'pro'] -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}