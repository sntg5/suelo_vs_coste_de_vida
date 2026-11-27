{# =============================================================================
   log_run_summary(results)
   =============================================================================
   Se ejecuta desde on-run-end (dbt_project.yml) al terminar cada dbt build,
   run, test, seed o snapshot. Recibe `results`, con el resultado de cada
   nodo, y escribe en el log un resumen con el entorno (target) y el número
   de nodos correctos, con aviso y con error. No lanza consultas a Snowflake.
   ============================================================================= #}
{% macro log_run_summary(results) %}
    {% if execute %}
        {% set ok = results | selectattr('status', 'in', ['success', 'pass']) | list | length %}
        {% set warn = results | selectattr('status', 'equalto', 'warn') | list | length %}
        {% set ko = results | selectattr('status', 'in', ['error', 'fail']) | list | length %}
        {{ log('Resumen [' ~ target.name ~ ']: ' ~ ok ~ ' OK, ' ~ warn ~ ' WARN, ' ~ ko ~ ' ERROR/FAIL', info=True) }}
    {% endif %}
{% endmacro %}