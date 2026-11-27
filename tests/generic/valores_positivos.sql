{# =============================================================================
   Test genérico: valores_positivos(model, column_name)
   =============================================================================
   Devuelve las filas en las que la columna es cero o negativa; si no devuelve
   ninguna, el test pasa. Los NULL no cuentan: de eso se encarga not_null.
   Se declara en el YAML como cualquier otro test, en la columna que se quiere
   comprobar:
     data_tests:
       - valores_positivos
   ============================================================================= #}
{% test valores_positivos(model, column_name) %}

SELECT
    {{ column_name }}
FROM {{ model }}
WHERE {{ column_name }} <= 0

{% endtest %}