#!/usr/bin/env python3
# =============================================================================
# convertir_xls_a_csv.py · Suelo urbano frente al coste de vida
# =============================================================================
# Convierte las tablas del Ministerio de Vivienda (MIVAU) publicadas en XLS
# (Excel 97) a CSV, SIN cambiar su contenido, para poder cargarlas en un stage
# de Snowflake (COPY INTO no lee ficheros .xls).
#
# Por qué un script y no "Guardar como CSV" en Excel:
#   - Excel guarda cada número tal como se ve en pantalla (formato de celda y
#     configuración regional): puede redondear decimales o cambiar separadores.
#   - Abrir y guardar el original con Excel puede modificarlo sin querer.
#   - El script es reproducible y queda versionado en el repositorio.
#
# Contrato del CSV de salida (es lo que esperan el FILE FORMAT y la UDF
# FN_TEXTO_A_NUMERO de Snowflake):
#   - separador ';', UTF-8 CON BOM y fin de línea CRLF: el mismo formato que los
#     CSV del INE. El BOM hace que Excel muestre bien tildes y eñes; sin él,
#     Excel lee el fichero como Windows-1252 y enseña "AndalucÃ­a" (el fichero
#     estaría bien, pero se vería mal). Snowflake ignora el BOM al cargar;
#   - TODAS las filas y columnas de la primera hoja, en el mismo orden
#     (cabeceras y notas incluidas: la limpieza se hace en dbt);
#   - textos tal cual, con sus espacios finales y los marcadores 'n.s.', 'n.s'
#     y '.' de "sin dato";
#   - números en formato español SIN separador de miles, igual que los CSV del
#     INE: coma decimal ('159,7') y enteros sin decimales ('7437'), con hasta 15
#     cifras significativas (la precisión con la que trabaja Excel);
#   - celdas vacías como campo vacío;
#   - comillas dobles solo cuando un campo contiene ';', comillas o saltos de
#     línea (csv.QUOTE_MINIMAL).
#
# Uso:
#   pip install xlrd==2.0.1
#   python scripts/convertir_xls_a_csv.py data/origen/36400500.XLS data/origen/36100500.XLS --salida data/csv
# =============================================================================

import argparse
import csv
from pathlib import Path

import xlrd


def formatear_celda(celda: xlrd.sheet.Cell) -> str:
    """Devuelve el texto de una celda según el contrato descrito arriba."""
    if celda.ctype in (xlrd.XL_CELL_EMPTY, xlrd.XL_CELL_BLANK):
        return ""
    if celda.ctype == xlrd.XL_CELL_TEXT:
        return celda.value  # texto sin tocar (ni trim ni cambios)
    if celda.ctype == xlrd.XL_CELL_NUMBER:
        valor = float(celda.value)
        if valor.is_integer():
            return str(int(valor))
        texto = format(valor, ".15g")
        if "e" in texto.lower():  # no debería pasar con estos datos
            raise ValueError(f"Número en notación científica: {valor!r}")
        return texto.replace(".", ",")
    if celda.ctype == xlrd.XL_CELL_BOOLEAN:
        return "TRUE" if celda.value else "FALSE"
    # Fechas o errores de Excel: en estas tablas no existen. Si aparecieran,
    # mejor parar y revisar que convertirlos sin saber qué son.
    raise ValueError(f"Tipo de celda inesperado ({celda.ctype}): {celda.value!r}")


def convertir(origen: Path, carpeta_salida: Path) -> Path:
    libro = xlrd.open_workbook(origen)  # ragged_rows=False: todas las filas con el mismo ancho
    hoja = libro.sheet_by_index(0)
    destino = carpeta_salida / f"{origen.stem}.csv"

    tipos = {"texto": 0, "numero": 0, "vacia": 0}
    with destino.open("w", encoding="utf-8-sig", newline="") as f:
        escritor = csv.writer(f, delimiter=";", quoting=csv.QUOTE_MINIMAL, lineterminator="\r\n")
        for i in range(hoja.nrows):
            fila = [formatear_celda(hoja.cell(i, j)) for j in range(hoja.ncols)]
            for j in range(hoja.ncols):
                ctype = hoja.cell_type(i, j)
                if ctype == xlrd.XL_CELL_NUMBER:
                    tipos["numero"] += 1
                elif ctype == xlrd.XL_CELL_TEXT:
                    tipos["texto"] += 1
                else:
                    tipos["vacia"] += 1
            escritor.writerow(fila)

    print(f"{origen.name} -> {destino}")
    print(f"  hoja '{hoja.name}': {hoja.nrows} filas x {hoja.ncols} columnas")
    print(f"  celdas: {tipos['numero']} numéricas, {tipos['texto']} de texto, {tipos['vacia']} vacías")
    return destino


def main() -> None:
    parser = argparse.ArgumentParser(description="Convierte XLS del MIVAU a CSV sin cambiar su contenido.")
    parser.add_argument("ficheros", nargs="+", type=Path, help="Ficheros .XLS de origen")
    parser.add_argument("--salida", type=Path, default=Path("data/csv"), help="Carpeta de salida")
    args = parser.parse_args()

    args.salida.mkdir(parents=True, exist_ok=True)
    for fichero in args.ficheros:
        convertir(fichero, args.salida)


if __name__ == "__main__":
    main()
