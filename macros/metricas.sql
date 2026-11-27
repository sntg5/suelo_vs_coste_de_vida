{# =============================================================================
   Macros de métricas: una métrica, un sitio
   =============================================================================
   Cada fórmula del catálogo de métricas se define una sola vez aquí y la
   usan los modelos de Gold. Todas protegen la división entre cero con NULLIF
   (si el denominador es 0, el resultado es NULL en vez de un error) y van
   entre paréntesis para poder usarlas dentro de otras expresiones.
   ============================================================================= #}

{# Media ponderada: suma del numerador entre suma del denominador. Va dentro
   de un GROUP BY. Ejemplo: precio medio = Σ precio_x_transacciones /
   Σ transacciones_con_precio. #}
{% macro media_ponderada(numerador, denominador) -%}
    (SUM({{ numerador }}) / NULLIF(SUM({{ denominador }}), 0))
{%- endmacro %}

{# Cociente entre dos valores ya calculados. #}
{% macro ratio(numerador, denominador) -%}
    ({{ numerador }} / NULLIF({{ denominador }}, 0))
{%- endmacro %}

{# Variación relativa frente a un valor de referencia: 0,083 = +8,3 %. #}
{% macro variacion_pct(actual, anterior) -%}
    ({{ actual }} / NULLIF({{ anterior }}, 0) - 1)
{%- endmacro %}

{# Variación real: la variación del precio descontada la del IPC. #}
{% macro variacion_real(variacion_precio, variacion_ipc) -%}
    ((1 + {{ variacion_precio }}) / NULLIF(1 + {{ variacion_ipc }}, 0) - 1)
{%- endmacro %}

{# Precio hipotético: el precio base actualizado con el IPC desde el año base. #}
{% macro precio_hipotetico(precio_base, ipc, ipc_base) -%}
    ({{ precio_base }} * {{ ipc }} / NULLIF({{ ipc_base }}, 0))
{%- endmacro %}