{# =============================================================================
   grant_select_on_gold(role, dry_run=true)  ·  macro para dbt run-operation
   =============================================================================
   Concede lectura sobre los esquemas de consumo de Gold (core y marts) a un
   rol, normalmente REPORTING_ROLE para Power BI:
     dbt run-operation grant_select_on_gold --args '{role: REPORTING_ROLE}'
   Por defecto (dry_run=true) solo escribe las sentencias en el log. Para
   ejecutarlas:
     dbt run-operation grant_select_on_gold --args '{role: REPORTING_ROLE, dry_run: false}'
   Las tablas y vistas de Gold que se recrean en cada dbt build (carga
   completa) pierden sus permisos, así que el job de PRO ejecuta esta macro
   después del build. El hecho incremental de vivienda no se recrea y
   conserva los suyos; volver a concederlos no cambia nada.
   El usage sobre la base de datos no se concede aquí: lo da el script de
   Snowflake 01_crear_entorno.sql, porque el rol de transformación no es
   propietario de la base y no puede concederlo.
   El nombre de cada esquema se resuelve con generate_schema_name: en
   desarrollo apunta a los esquemas personales y en DEV y PRO a los
   definitivos.
   Alternativa declarativa: la config +grants en dbt_project.yml, que dbt
   aplica cada vez que construye un modelo.
   ============================================================================= #}
{% macro grant_select_on_gold(role, dry_run=true) %}

    {% set database = env_var('DBT_GOLD_DB') %}

    {% for custom_schema in ['core', 'marts'] %}
        {% set schema = generate_schema_name(custom_schema, none) | trim %}
        {% set statements = [
            'GRANT USAGE ON SCHEMA ' ~ database ~ '.' ~ schema ~ ' TO ROLE ' ~ role,
            'GRANT SELECT ON ALL TABLES IN SCHEMA ' ~ database ~ '.' ~ schema ~ ' TO ROLE ' ~ role,
            'GRANT SELECT ON ALL VIEWS IN SCHEMA ' ~ database ~ '.' ~ schema ~ ' TO ROLE ' ~ role
        ] %}
        {% for sql in statements %}
            {% if dry_run %}
                {{ log('[dry_run] ' ~ sql, info=True) }}
            {% else %}
                {% do run_query(sql) %}
                {{ log('Ejecutado: ' ~ sql, info=True) }}
            {% endif %}
        {% endfor %}
    {% endfor %}

{% endmacro %}