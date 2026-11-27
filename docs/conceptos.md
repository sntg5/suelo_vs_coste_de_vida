{% docs precio_hipotetico %}
Precio que tendría el suelo si, desde el año base (variable `anio_base`, 2018), hubiera subido igual que el coste de vida (IPC) de su provincia.

Por provincia y trimestre se calcula como `precio_base × ipc_trimestral / ipc_medio_base`:

- `precio_base`: precio medio de la provincia en el año base, ponderado por sus transacciones con precio;
- `ipc_trimestral`: media de los 3 meses del Índice general de la provincia;
- `ipc_medio_base`: media del Índice general de la provincia en el año base.

Por encima de la provincia (CCAA, zona y España) se agrega con los mismos pesos que el precio real (`hipotetico_x_transacciones / transacciones_con_precio`). Por eso, en esos niveles, es el coste de vida ponderado por compraventas de suelo, no el IPC oficial de la CCAA ni el de España.

La fórmula vive en la macro `precio_hipotetico` del catálogo de métricas (`macros/metricas.sql`).
{% enddocs %}

{% docs fiabilidad %}
Marca de fiabilidad del precio del suelo. Un trimestre de una provincia es poco fiable si tiene menos compraventas de suelo que la variable `umbral_fiabilidad` (20 por defecto): con tan pocas operaciones, el precio medio puede cambiar mucho por unas pocas ventas.

En el periodo 2018-2025 son poco fiables 169 de los 1.600 trimestres, sobre todo en provincias con poco mercado de suelo (Gipuzkoa, Ourense, Teruel, Lugo, Soria...). El dato no se quita: se marca, para que los informes lo avisen.
{% enddocs %}

{% docs etapa %}
Fase del periodo respecto a la pandemia. Las etapas se definen por años en `seed_etapas` y Silver las asigna a cada año en `slv_anio`.

| Código | Etapa | Años |
|---|---|---|
| PRE | Prepandemia | 2018-2019 |
| PAN | Pandemia | 2020 |
| REC | Recuperación | 2021-2022 |
| POS | Pospandemia | 2023-2025 |

La pospandemia empieza en 2023 porque la OMS dio por terminada la emergencia sanitaria internacional el 5 de mayo de 2023. En los gráficos las etapas se ordenan por `orden_etapa`, no por su nombre.
{% enddocs %}

{% docs nivel_territorio %}
Nivel territorial de la fila. Los marts de los casos 1 y 3 tienen 4 niveles (Provincia, CCAA, Zona y España) y el del caso 2 tiene 2 (Provincia y España). España es la suma de las 50 provincias del análisis, sin Ceuta ni Melilla.

Los niveles se calculan en dbt con `GROUPING SETS`. Los códigos de `id_territorio` se repiten entre niveles (`09` es Burgos como provincia y Cataluña como CCAA; España es `ES`), así que **siempre hay que filtrar por `nivel`** antes de comparar o sumar.
{% enddocs %}