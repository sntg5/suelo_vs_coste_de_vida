# Datos de origen

Los ficheros de datos **no se suben al repositorio**: son públicos, pesan unos 65 MB y se pueden volver a descargar. Este documento explica de dónde salen, cómo se preparan y qué se comprobó al descargarlos.

## 1. Ficheros y fuentes

| Fichero | Fuente | URL de descarga | Formato |
|---|---|---|---|
| `36400500.XLS` | Ministerio de Vivienda y Agenda Urbana (MIVAU). Estadística de Precios de Suelo Urbano, tabla 4: precio medio del m² de suelo urbano por CCAA y provincias | https://apps.fomento.gob.es/BoletinOnline2/sedal/36400500.XLS | XLS (Excel 97) |
| `36100500.XLS` | MIVAU. Misma estadística, tabla 1: número total de transacciones de suelo por CCAA y provincias | https://apps.fomento.gob.es/BoletinOnline2/sedal/36100500.XLS | XLS (Excel 97) |
| `50918.csv` | Instituto Nacional de Estadística (INE). IPC, tabla 50918: índices provinciales, general y de grupos ECOICOP (base 2021) | https://www.ine.es/jaxiT3/files/t/csv_bdsc/50918.csv | CSV `;` |
| `6150.csv` | INE. Estadística de Transmisiones de Derechos de la Propiedad, tabla 6150: compraventa de viviendas según régimen y estado, mensual, por provincias | https://www.ine.es/jaxiT3/files/t/csv_bdsc/6150.csv | CSV `;` |

Fecha de descarga: **18-nov-2026**. Reutilización libre citando la fuente (MIVAU e INE).

Huellas SHA-256 de los ficheros descargados (sirven para comprobar que son exactamente los mismos):

| Fichero | Bytes | SHA-256 |
|---|---|---|
| `36400500.XLS` | 96.256 | `528d560f3173e48447a465850a89515d02d462dd18657f04a92833a7c55d3c98` |
| `36100500.XLS` | 365.568 | `1514462532dd84ab077ef542e0c6402edeed113b4f425468b3c2d29d06a49710` |
| `50918.csv` | 59.504.421 | `eb580d2f5cff07d4c90a08e06580ec36f2b73a35d2ab0fb4089e64c8914a118f` |
| `6150.csv` | 5.999.305 | `5c8a9dc49468223bc9e76a4b7316c2f8f918792706bb697db0f9bbd1952a806e` |

Las fuentes se actualizan periódicamente. Si se descargan otro día pueden traer meses o trimestres nuevos; el proyecto filtra el periodo 2018-2025, así que el resultado no cambia salvo que la fuente revise datos antiguos.

## 2. Estructura de carpetas (en local)

```
data/
├── README.md        ← este fichero (el único que se sube a GitHub)
├── origen/          ← los 4 ficheros tal como se descargan, sin abrir ni guardar con Excel
└── csv/             ← los 2 XLS del ministerio convertidos a CSV
```

## 3. Conversión XLS → CSV

`COPY INTO` de Snowflake no lee ficheros `.XLS`. Los dos ficheros del ministerio se convierten con un script que **no cambia el contenido**:

```bash
pip install xlrd==2.0.1
python scripts/convertir_xls_a_csv.py data/origen/36400500.XLS data/origen/36100500.XLS --salida data/csv
```

Formato del CSV resultante:
- separador `;`, UTF-8 **con BOM** y fin de línea CRLF: el mismo formato que los CSV del INE. Con el BOM, Excel muestra bien tildes y eñes;
- todas las filas y las 94 columnas de la hoja;
- textos tal cual, incluidos los espacios finales y los marcadores `n.s.`, `n.s` y `.`;
- números en formato español sin separador de miles (`159,7`, `7437`), igual que los CSV del INE.

| Fichero convertido | Filas | SHA-256 |
|---|---|---|
| `csv/36400500.csv` | 83 | `74ba5285a8afb42fb40b530a36fbb850ab139729dc07e2a30912118539a2f950` |
| `csv/36100500.csv` | 85 | `8c03d247a8bb23b27baf642a69ecf238af7ffbb6188bcb55cadd863aa5b09091` |

Los dos ficheros del INE no se convierten: se suben tal cual.

Los CSV convertidos conservan la hoja tal como la publica el ministerio:
- filas vacías;
- título (filas 7-10);
- cabecera de 3 filas (11-13);
- datos (desde la fila 14).

Es a propósito: el ministerio publica un informe pensado para leerlo, no un dataset, y convertirlo en tablas limpias es el trabajo de dbt (staging y Silver). Además, el número de línea del CSV coincide con la fila de Excel, así que cualquier dato de Bronze se puede rastrear hasta la celda original.

## 4. Ficheros que se suben al stage de Snowflake

| Fichero | Tabla de Bronze | Filas esperadas tras la carga |
|---|---|---|
| `csv/36400500.csv` | `MIVAU.PRECIO_SUELO` | 83 (hoja completa, con cabeceras) |
| `csv/36100500.csv` | `MIVAU.TRANSACCIONES_SUELO` | 85 (hoja completa, con cabeceras) |
| `origen/50918.csv` | `INE.IPC_PROVINCIAL` | 793.728 (sin la cabecera) |
| `origen/6150.csv` | `INE.COMPRAVENTA_VIVIENDAS` | 85.320 (sin la cabecera) |

## 5. Comprobaciones hechas el 18-nov-2026

**Precio del suelo (tabla 4) y transacciones (tabla 1):**
- 62 y 64 filas de datos (filas 14 a 75 y 14 a 77 de Excel). Mezclan total nacional, comunidades autónomas y provincias en la misma columna.
- 90 columnas de trimestres, del 1T 2004 al 2T 2026. Cada periodo se asigna por posición, porque en la tabla 1 la columna del 4T 2023 no tiene etiqueta.
- Marcadores de "sin dato" en la tabla 4: `n.s.` 55, `n.s` 4 y `.` 15. En las provincias, en 2018-2025, solo faltan Ávila 2T 2020, Soria 2T 2020 y Ourense 2T 2024.
- Las 50 provincias cruzan con la tabla de correspondencia del proyecto.
- La suma de provincias más Ceuta y Melilla coincide con el total nacional de transacciones.
- La media de precios ponderada por transacciones reproduce el total nacional con diferencias de −1,9 % a +1,5 %.

**IPC (50918):**
- UTF-8 con BOM, CRLF, coma decimal.
- 793.728 filas; 53 territorios, 13 grupos, 4 tipos de dato y 288 meses (2002M01-2025M12).
- 50 de 50 provincias cruzan con la tabla de correspondencia.

**Compraventa de viviendas (6150):**
- UTF-8 con BOM, CRLF, punto como separador de miles y sin valores vacíos.
- 85.320 filas = 72 territorios (nacional, 19 CCAA y ciudades autónomas, 52 provincias) × 5 categorías × 237 meses (2007M01-2026M09).
- La jerarquía viene en 3 columnas: `Total Nacional`, `Comunidades y Ciudades Autónomas` y `Provincias`.
- 50 de 50 provincias cruzan con la tabla de correspondencia. La comunidad autónoma de cada provincia coincide con la del proyecto.
- Sin huecos en 2018-2025.
- Coherencia exacta en todos los meses de las 52 provincias:
  - libre + protegida = total;
  - nueva + usada = total;
  - suma de provincias = total nacional;
  - suma de las provincias de cada CCAA = CCAA.

**Peso de Ceuta y Melilla (excluidas del análisis):** 0,03 % de las compraventas de suelo y 0,19 % de las de vivienda en 2018-2025.
