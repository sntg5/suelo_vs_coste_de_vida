# Registro de decisiones

Las decisiones del proyecto, siempre en el mismo formato: **qué se decidió, qué regla o principio se aplicó y por qué**, con datos reales. El detalle del modelo (diccionario, normalización paso a paso y métricas) está en [`diseno_modelo.md`](diseno_modelo.md) y el resumen del proyecto, en el [`README`](../README.md).

## 1. Alcance y tema

| Decisión | Regla | Por qué |
|---|---|---|
| Tema: precio del suelo urbano frente al IPC por provincias, con la compraventa de viviendas como termómetro del mercado | Alcance | Datos oficiales, actuales y gratuitos; mapa por provincias; un periodo que cubre antes, durante y después de la pandemia; hallazgos que se pueden contrastar |
| Periodo 2018-2025 con variables (`anio_inicio`, `anio_fin`, `anio_base`) | Alcance | Bronze guarda la serie completa y Silver filtra: cambiar el periodo es cambiar una variable, no el código |
| 50 provincias, sin Ceuta ni Melilla | Alcance | Pesan el 0,03 % de las compraventas de suelo y el 0,19 % de las de vivienda, y en la tabla 4 del ministerio van juntas y con 29 huecos. Se quedan en Bronze y en los tests de conciliación |
| 4 casos de uso y 12 tablas en Silver | Alcance | Alcance acotado desde el principio: lo esencial bien hecho antes que todo a medias |
| "IPC" o "coste de vida", nunca "inflación"; siempre desde quien compra | Comunicación | Es lo que mide la fuente y lo que entiende quien quiere comprarse una vivienda |

## 2. Arquitectura y entornos

| Decisión | Regla | Por qué |
|---|---|---|
| Solo DEV y PRO, sin PRE | Entornos | En un proyecto de una persona nadie valida antes de producción; PRE duplicaría bases, rol, clon y job sin aportar nada |
| Bronze se carga en PRO y DEV es un clon zero-copy de PRO | Entornos | Los datos entran por producción y DEV recibe una copia que no duplica el almacenamiento. Las entregas simuladas van solo a DEV y se limpian volviendo a clonar (`04_clonar_bronze.sql`) |
| El código va de DEV a PRO: rama → pull request → merge → job de DEV → job de PRO | Entornos | Datos y código van en sentidos distintos: nada llega a PRO sin pasar por un pull request y por DEV |
| Staging dentro de `{ENV}_SILVER_DB`, sin base propia | Diseño | Staging son vistas de paso, no una capa que se consuma |
| `generate_schema_name` con los targets `dev` y `pro` | Entornos | En DEV y PRO los esquemas tienen su nombre limpio (`silver`, `core`…); en desarrollo, cada persona trabaja en sus esquemas personales |
| Warehouse XS con autosuspensión y jobs lanzados a mano | Coste | Poco volumen (unas 880.000 filas en Bronze, 83.426 en Silver) y una sola persona que lo mantiene |
| Batch, sin streaming ni microbatch | Diseño | El INE publica cada mes y el ministerio, cada trimestre |

## 3. Ingesta y Bronze (Snowflake)

| Decisión | Regla | Por qué |
|---|---|---|
| Los XLS del ministerio se convierten a CSV con un script (`scripts/convertir_xls_a_csv.py`) | Trazabilidad | `COPY INTO` no lee `.XLS`. Guardar como CSV desde Excel puede redondear o cambiar separadores; el script no cambia el contenido y es reproducible |
| Tablas raw con todas las columnas en `VARCHAR` más `_loaded_at`, `_fichero` y `_fila` | Trazabilidad | Los ficheros traen `n.s.`, `.`, coma decimal y punto de miles: los tipos se fijan después, en dbt. `_fila` lleva cada dato hasta su fila del fichero (en el ministerio, la fila de Excel) |
| Se carga la hoja completa del ministerio, con títulos y cabeceras | Trazabilidad | El ministerio publica un informe pensado para leerlo, no un dataset: convertirlo en tablas limpias es trabajo de dbt |
| Procedimiento `SP_CARGAR_BRONZE`: `TRUNCATE` + `COPY INTO`, con auditoría y derechos del propietario | Idempotencia | Repetir la carga deja lo mismo (`03b_prueba_idempotencia.sql`: mismas filas y misma huella `HASH_AGG`). Con derechos del propietario se delega la carga sin dar escritura en Bronze, y cada carga queda en `AUDITORIA_CARGAS` |
| Una UDF para los números de las 4 fuentes (`FN_TEXTO_A_NUMERO`) y otra para los periodos del INE (`FN_PERIODO_INE_A_FECHA`) | Una métrica, un sitio | El mismo problema (`n.s.`, coma decimal, punto de miles) se resuelve en un solo sitio |
| Sesiones sin roles secundarios (`default_secondary_roles = ()`) | Seguridad | Por defecto Snowflake activa todos los roles del usuario y una sesión de DEV podía leer PRO |
| dbt y Power BI se conectan con par de claves | Seguridad | El usuario tiene MFA obligatorio. La clave privada y su passphrase se guardan en un gestor de contraseñas, nunca en el repositorio |
| Los scripts obtienen el usuario con `current_user()` | Seguridad | El nombre del usuario no queda escrito en un repositorio público |

## 4. Silver: modelado y normalización

| Decisión | Regla | Por qué |
|---|---|---|
| 12 tablas en 3FN a partir de las 4 fuentes y de un seed desnormalizado | Normalización | Cada dato en la tabla de la clave de la que depende. El paso a paso de 1FN a 3FN, con los datos sucios reales, está en `diseno_modelo.md` (§2) |
| La clave de provincia y de CCAA es el código del INE, no el nombre | Claves | Cada fuente escribe distinto el mismo sitio: `Vizcaya` / `48 Bizkaia`, `Avila` / `05 Ávila`, `Guipúzcoa` / `20 Gipuzkoa` |
| El ministerio se cruza por nombre con `seed_provincias.nombre_mivau` | Origen | Su Excel no trae códigos: se cruza por el nombre exacto, sin los espacios finales |
| Nunca se cruza por un código sin saber de qué nivel es | Claves | En la tabla 6150, `09` es Cataluña (CCAA) y también Burgos (provincia) |
| Las provincias salen del seed y el calendario de `date_spine`, no de los datos | Origen | Si a una fuente le faltara un periodo o una provincia, el test de completitud lo detecta |
| El periodo del ministerio se asigna por la posición de la columna | Origen | El 4T 2023 no tiene etiqueta en la tabla 1 y hay cabeceras con espacios (`'Año 2011 '`) |
| No se guardan los totales que se pueden calcular (nacional, CCAA, `Viviendas: Total`) | Redundancia | La suma de provincias cuadra con el total nacional y libre + protegida = nueva + usada = total en el 100 % de los casos. Se usan solo en los tests de conciliación |
| Sí se guarda el Índice general del IPC | Redundancia (excepción) | Es el total de los 12 grupos, pero no se puede recalcular sin las ponderaciones del INE |
| No se guardan las variaciones publicadas | Redundancia | Se calculan en Gold a partir del índice o del precio |
| `n.s.` → NULL (3 precios: Ávila y Soria 2T 2020, Ourense 2T 2024) | Nulos | Un 0 hundiría las medias e interpolar sería inventar el dato; las transacciones de esos trimestres sí existen |
| Zona como tabla; `criterio` como atributo; `orden_etapa` | Diseño | La zona es un nivel de análisis (Norte frente a Sur); `criterio` solo tiene 2 valores y ningún atributo propio; las etapas no salen en orden alfabético |
| Códigos de vivienda en palabras (`LIBRE`, `PROTEGIDA`, `NUEVA`, `USADA`) | Diseño | `PRO` se confundía con el entorno PRO, y el bucle Jinja de Gold genera `num_libre`… a partir del propio código |
| Prefijo `id_` en las claves naturales y `sk_` en las subrogadas (solo en Gold) | Claves | Una regla para todo el modelo; Gold queda aislado de la numeración de la fuente |
| Tipos con `CAST` y restricciones con tests, sin contratos de dbt | Calidad | Snowflake no hace cumplir PK, FK ni UNIQUE: los tests sí lo comprueban. Los contratos quedan como siguiente paso |
| Etapas: `PRE` 2018-2019, `PAN` 2020, `REC` 2021-2022, `POS` 2023-2025 | Diseño | La OMS dio por terminada la emergencia sanitaria internacional el 5-may-2023. Las etapas viven en un seed: cambiar una es cambiar una fila |

## 5. Gold y marts

| Decisión | Regla | Por qué |
|---|---|---|
| Estrella con 3 hechos (fotos periódicas) y 3 dimensiones | Grano | 3 fuentes, 3 granos y 3 ritmos de publicación: un hecho por proceso y por grano. Juntarlos obligaría a inventar meses de suelo o a repetir cada dato de vivienda 13 veces |
| `dim_lugar` y `dim_tiempo`, conformadas | Grano | Un filtro de CCAA o de etapa llega a los 3 hechos, y los casos 2 y 3 pueden cruzar suelo y vivienda |
| `dim_tiempo` a grano mes; el suelo se une por el primer mes del trimestre | Grano | El ministerio no publica meses: repartir un trimestre entre 3 meses sería inventar datos |
| El tipo de vivienda va en columnas, no como dimensión | Aditividad | Sus dos criterios parten el mismo total: como dimensión se sumaría dos veces |
| Estrella, no copo de nieve | Diseño | CCAA, zona, etapa y año son niveles de una jerarquía dentro de su dimensión |
| `sk_` con `generate_surrogate_key`; `id_mes` como clave natural | Claves | Práctica de Kimball. AAAAMM es estable, legible y ordena bien: una subrogada no aportaría nada |
| Numerador y denominador en el hecho del suelo (`precio_x_transacciones`, `transacciones_con_precio`) | Aditividad | Un precio medio no se promedia: Soria, con pocas compraventas, pesaría lo mismo que Madrid |
| `hipotetico_x_transacciones` (D13) | Aditividad | El precio real y el hipotético se agregan con los mismos pesos, para que la comparación sea homogénea |
| Marca `es_fiable` (menos de 20 compraventas en el trimestre) en lugar de quitar el dato | Calidad | 169 de 1.600 trimestres son poco fiables: se avisan, no se borran |
| 4 marts como vistas, uno por caso de uso | Diseño | Son las respuestas a las 4 preguntas, calculadas una vez en dbt y con tests; como vistas, siempre reflejan Gold |
| Casos 1 y 3 en 4 niveles con `GROUPING SETS` (D14) | Una métrica, un sitio | Los KPIs de CCAA, zona y España salen de dbt, no de DAX |
| El IPC no se agrega por encima de la provincia (D15) | Aditividad | Faltan las ponderaciones del INE. La cifra de España es el IPC Nacional, como referencia |
| Titular de España = variación real; lectura principal por provincia (D19) | Comunicación | Efecto composición: las 10 provincias más caras pasan del 37,2 % al 30,1 % de las compraventas de suelo. La cesta fija de 2018 (`analyses/cesta_fija_2018.sql`) llega a la misma conclusión: −1,3 % |
| Ávila 2025 no se toca | Calidad | Es un dato real pero atípico (3T 2025: 468 compraventas a 20,16 €/m²): se avisa en el informe |

## 6. Métricas y KPIs

| Decisión | Regla | Por qué |
|---|---|---|
| Las fórmulas viven en macros (`macros/metricas.sql`) | Una métrica, un sitio | Cada fórmula se escribe una vez y la usan todos los modelos. El plan gratuito de dbt no incluye el Semantic Layer: las macros hacen de capa semántica ligera |
| Buena Compra (KPI principal): precio medio < precio hipotético | KPI | "El suelo cuesta menos de lo que costaría si desde 2018 hubiera subido como el coste de vida" |
| Buena Venta (KPI secundario): la diferencia mejora respecto al año anterior | KPI | La posición del suelo frente al coste de vida mejora: es bueno para quien vende |
| Los KPIs y el ranking del caso 4 son nulos en 2018 | KPI | Es el año base: no hay con qué comparar |
| `nombre_grupo_corto` se define en dbt | Una métrica, un sitio | Un rótulo, un sitio: "Vivienda (alquiler y suministros)" deja claro que el IPC no incluye la compra de vivienda |

## 7. dbt: calidad y operación

| Decisión | Regla | Por qué |
|---|---|---|
| Cada test explica qué significa el fallo ("Si falla, revisar…") | Calidad | Quien vea el fallo sabe qué mirar sin abrir el SQL |
| Tests singulares de completitud, conciliación y coherencia | Calidad | Comprueban contra los totales oficiales que no se pierde ni se duplica nada al pasar de columnas a filas |
| `severity: warn` en 2 tests y umbrales 200 / 400 en la marca de fiabilidad | Calidad | Lo esperable avisa; un error de verdad para el job de PRO, no se reconstruyen los marts afectados y Power BI conserva la última versión buena |
| `store_failures` en el esquema `dbt_jobs` | Calidad | Las filas que fallan quedan guardadas para revisarlas |
| Freshness sobre `_loaded_at`: aviso a los 35 días y error a los 100 | Operación | El INE publica cada mes y el ministerio, cada trimestre |
| Hook `log_run_summary` y aviso por email de los jobs | Operación | Cada ejecución deja un resumen OK / WARN / ERROR y avisa si algo va mal |
| Permisos de `REPORTING_ROLE` como último paso del job de PRO (`grant_select_on_gold`) | Seguridad | `dbt build` recrea las tablas y vistas de carga completa y se pierden los permisos: cada despliegue termina dándolos. Alternativa: `+grants` en `dbt_project.yml` |
| `+transient: false` | Operación | Tablas permanentes, con Fail-safe |
| 5 selectores, 4 analyses, una exposure y bloques de documentación | Operación | Selecciones con nombre (`entrega_vivienda`: lo que se reconstruye cuando el INE publica), consultas de comprobación, linaje hasta Power BI y definiciones escritas una sola vez |

## 8. Carga incremental (vivienda)

| Decisión | Regla | Por qué |
|---|---|---|
| Incremental solo en la rama de vivienda | Incremental | Es la única fuente que crece cada mes y corrige sus datos provisionales durante un año (el 25-sep-2026 el INE actualizó julio-diciembre de 2025). Suelo e IPC son series cerradas y pequeñas para 2018-2025 |
| Silver con `merge` (clave provincia, mes y tipo) | Incremental | Hay una fila por clave cuyo valor el INE corrige: `merge` actualiza lo que cambió e inserta lo nuevo |
| Gold con `delete+insert` (clave `sk_lugar` e `id_mes`) | Incremental | La ventana se recalcula entera (todas las columnas y la variación interanual): borrar el bloque y reescribirlo es lo natural. Así se ven las dos estrategias |
| Ventana de 12 meses en una macro (`ventana_revision`, variable `meses_revision`) | Incremental | Política del INE: los datos provisionales se revisan al publicar el mismo periodo del año siguiente. Es una variable: se cambia sin tocar el código |
| Se filtra por el mes del dato y no por `_loaded_at` | Incremental | Bronze sustituye el fichero completo y `_loaded_at` cambia en todas las filas: con ese filtro se procesaría todo |
| Bronze sigue con carga completa | Idempotencia | Guarda la entrega tal como llega (auditoría) y `TRUNCATE` + `COPY` es idempotente; acumular entregas obligaría a quitar duplicados sin ganar nada. El incremental empieza donde se transforma |
| Cadena coherente | Incremental | Después de Silver incremental, todo es incremental (Gold) o vista (marts): nunca hay una carga completa detrás de un incremental |
| Silver solo crea los meses hasta el último publicado por el INE | Incremental | Si no, una entrega con datos hasta octubre crearía noviembre y diciembre vacíos y la ventana empezaría en el mes equivocado |
| `on_schema_change: append_new_columns` | Operación | Una columna nueva se añade sin parar el job de PRO; con `fail` el job también se pararía por un cambio de tipo |
| Sin microbatch | Alcance | Necesitaría una columna `event_time` nueva (que afectaría a Power BI) y procesa mes a mes, así que el LAG de 12 meses no vería el año anterior |
| Idempotencia comprobada | Idempotencia | La ventana se recalcula desde la fuente y `merge` y `delete+insert` reemplazan por clave: dos ejecuciones seguidas dejan las mismas filas y los mismos valores |

## 9. Snapshot

| Decisión | Regla | Por qué |
|---|---|---|
| `snp_compraventa_vivienda`: SCD2 con estrategia `check` sobre `num_compraventas` | Historial | Guarda cada versión de un dato que el INE corrige; el incremental solo guarda el último valor. Revisión real: diciembre de 2025 tenía 54.148 compraventas en el dato provisional (20-feb-2026) y 54.272 en el fichero descargado |
| `check` y no `timestamp` | Historial | El INE no publica una fecha de modificación por dato y `_loaded_at` cambia en cada carga: con `timestamp`, todas las filas tendrían una versión nueva en cada carga |
| Sobre Silver y no sobre la fuente | Historial | Bronze no tiene una clave estable (mezcla 3 niveles y `_fila` cambia en cada entrega); Silver tiene una clave natural limpia y, en esta tabla, solo reorganiza el dato |
| No transient | Historial | Un snapshot no se puede reconstruir: guarda lo que vio cuando se ejecutó |

## 10. Power BI

| Decisión | Regla | Por qué |
|---|---|---|
| Importación desde `PRO_GOLD_DB` con `REPORTING_ROLE` | Seguridad | El informe solo ve `core` y `marts` de PRO; no ve Silver ni DEV |
| Marts sin relaciones; la estrella solo para la página "Explorar" | Diseño | Los marts mezclan niveles y sus cifras no se pueden sumar: una relación las volvería a agregar mal. La estrella demuestra que un filtro llega a la vez al suelo y a la vivienda |
| 4 tipos de medidas DAX y ningún `AVERAGE` | Una métrica, un sitio | Los cálculos están en dbt: Power BI solo lee, suma y divide sumas |
| `SELECTEDVALUE` para leer las cifras de los marts | Calidad | Si hubiera más de una fila, sale en blanco en vez de un número falso |
| Filtros fijos por visual en lugar de segmentadores | Visualización | Cada visual lee una sola fila del mart con su nivel, y el informe se lee de un vistazo |
| Columna `PAIS` añadida en Power Query a los marts | Visualización | Azure Maps situaba Córdoba en Argentina; con el país como contexto, las 50 provincias quedan en España. No cambia ningún valor |
| Caso 2: barras con las 10 provincias de mayor caída en mayo de 2020 en lugar de un mapa | Visualización | Una caída se compara mejor en barras ordenadas |
| Avisos en subtítulos y tooltips | Visualización | Ávila 2025 y los trimestres poco fiables se ven sin cuadros de texto largos |
| Las páginas se llaman como declara la exposure | Calidad | El linaje de dbt y el informe cuentan lo mismo |

## 11. GitHub y seguridad

| Decisión | Regla | Por qué |
|---|---|---|
| Un solo repositorio, que es también el proyecto dbt | Git | dbt Platform lee el proyecto de la raíz y todo el pipeline queda versionado junto |
| Un pull request por fase, con commits en español y con prefijo (`feat:`, `fix:`, `test:`, `docs:`, `chore:`) | Git | El historial cuenta cómo se construyó el proyecto, por iteraciones |
| Revisión de "Files changed" antes de cada merge | Seguridad | Se buscan `BEGIN ENCRYPTED`, `PRIVATE KEY` y el usuario de Snowflake |
| Los datos no se suben; solo `data/README.md` | Seguridad | Son públicos y se pueden volver a descargar; `data/README.md` guarda las URLs, la fecha de descarga y las huellas SHA-256 |
| `.gitignore` con claves, perfiles y artefactos de dbt | Seguridad | `*.p8`, `*.pem`, `*.key`, `.env`, `profiles.yml`, `target/`, `dbt_packages/` y `logs/` |
| La documentación general va en `documentacion/` | Diseño | `docs/` es la carpeta de dbt para los bloques `{% docs %}` |

## 12. Entregas simuladas

Para demostrar el incremental y el snapshot hacían falta entregas del INE distintas del fichero real. Se cargaron solo en Bronze de DEV, con SYSADMIN y con `SP_CARGAR_BRONZE`; **PRO nunca recibe una entrega simulada**. Los ficheros no están en el repositorio; sí el script que genera la entrega del incremental. Se reproduce lo que el INE hace de verdad: el 25-sep-2026 corrigió julio-diciembre de 2025.

| Fichero | Para qué | Cómo se generó | Dónde se cargó |
|---|---|---|---|
| `6150_entrega_1.csv` | Demo del incremental: la tabla 6150 tal como se habría publicado con datos hasta octubre de 2025 | Con `scripts/generar_entrega_1.py`, a partir del `6150.csv` real: quita los periodos posteriores a 2025M10 y trata julio-octubre de 2025 como provisionales. En cada provincia (sin Ceuta ni Melilla) resta d = máx(1, redondeo del 2 % del total) a vivienda libre, vivienda usada y total, y resta la suma de esos ajustes en su comunidad autónoma y en el total nacional. Se siguen cumpliendo libre + protegida = nueva + usada = total y las sumas por niveles. Mismo formato que el original (UTF-8 con BOM, CRLF, `;` y punto de miles): 81.360 filas | Stage y Bronze de DEV. Se carga, se reconstruye con `dbt run --full-refresh --selector entrega_vivienda` y después se carga el `6150.csv` real con `dbt build --selector entrega_vivienda`: el incremental corrige julio-octubre y añade noviembre y diciembre |
| `6150_simulada.csv` | Demo del snapshot: una revisión del INE | Copia del `6150.csv` real con 120 compraventas más en Madrid, diciembre de 2025, en vivienda libre, vivienda usada y total (sigue siendo coherente). Es del mismo orden que la revisión real de diciembre de 2025 en España (+124) | Stage y Bronze de DEV; se retiró volviendo a ejecutar `04_clonar_bronze.sql`. El historial de esa demo queda en los esquemas de desarrollo |

## 13. Fuera de alcance (siguientes pasos)

| Decisión | Regla | Por qué |
|---|---|---|
| Sin contratos de modelos, `groups` y `access` ni versiones de modelos | Alcance | Son útiles con varios equipos o consumidores. Aquí los tipos se fijan con `CAST` y los tests vigilan las restricciones |
| Sin unit tests ni job de CI en cada pull request | Alcance | Son el siguiente paso natural para validar la lógica antes del merge |
| Sin `pre_hook` ni `post_hook` | Alcance | El hook `on-run-end` y la macro de permisos cubren lo necesario |
| Sin Fivetran, APIs ni tiempo real | Alcance | Son ficheros oficiales que se publican cada mes o cada trimestre: la carga por fichero es suficiente |
| Sin el precio de la vivienda ni el alquiler | Alcance | Siguiente paso de análisis: completaría la visión de quien quiere comprar |
