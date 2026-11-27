"""Genera la entrega simulada de la tabla 6150 del INE para la demostración del incremental.

La entrega 1 es la tabla 6150 tal como se habría publicado con datos hasta octubre de 2025:
- quita los periodos posteriores a 2025M10;
- trata julio-octubre de 2025 como datos provisionales: en cada provincia (sin Ceuta ni Melilla)
  resta d = max(1, round(2 % del total)) a "Vivienda libre", "Vivienda usada" y "Viviendas: Total",
  y resta la suma de esos ajustes en su comunidad autónoma y en el total nacional.

Así se siguen cumpliendo libre + protegida = nueva + usada = total y las sumas por niveles.
La entrega 2 es el fichero 6150.csv real, que añade noviembre y diciembre de 2025 y corrige
julio-octubre. Las dos se cargan solo en Bronze de DEV.

Mantiene el formato del original: UTF-8 con BOM, fin de línea CRLF, separador ";" y punto de miles.

Uso: python generar_entrega_1.py <ruta de 6150.csv> <ruta de 6150_entrega_1.csv>
"""
import sys
from collections import defaultdict

ULTIMO_PERIODO = "2025M10"
PROVISIONALES = {"2025M07", "2025M08", "2025M09", "2025M10"}
EXCLUIDAS = {"51 Ceuta", "52 Melilla"}
TOTAL = "Viviendas: Total"
LIBRE = "Vivienda libre"
USADA = "Vivienda usada"


def a_entero(texto):
    return int(texto.replace(".", ""))


def a_texto(numero):
    return f"{numero:,}".replace(",", ".")


def main(origen, salida):
    with open(origen, encoding="utf-8-sig", newline="") as f:
        lineas = f.read().split("\r\n")
    cabecera = lineas[0]
    filas = [
        linea.split(";")
        for linea in lineas[1:]
        if linea and linea.split(";")[4] <= ULTIMO_PERIODO
    ]

    # Valores de cada provincia en los meses provisionales
    valor = {}
    ccaa_de = {}
    for _, ccaa, prov, cat, per, total in filas:
        if prov and prov not in EXCLUIDAS and per in PROVISIONALES:
            valor[(prov, cat, per)] = a_entero(total)
            ccaa_de[prov] = ccaa

    # Ajuste de cada provincia y mes, y su suma por comunidad autónoma y para España
    ajuste = {}
    suma_ccaa = defaultdict(int)
    suma_nacional = defaultdict(int)
    for (prov, cat, per), total in valor.items():
        if cat != TOTAL:
            continue
        d = max(1, round(total * 0.02))
        d = min(d, valor[(prov, LIBRE, per)], valor[(prov, USADA, per)])
        ajuste[(prov, per)] = d
        suma_ccaa[(ccaa_de[prov], per)] += d
        suma_nacional[per] += d

    resultado = []
    for nacional, ccaa, prov, cat, per, total in filas:
        if per in PROVISIONALES and cat in (TOTAL, LIBRE, USADA):
            if prov and prov not in EXCLUIDAS:
                total = a_texto(a_entero(total) - ajuste[(prov, per)])
            elif ccaa and not prov:
                total = a_texto(a_entero(total) - suma_ccaa.get((ccaa, per), 0))
            elif not ccaa and not prov:
                total = a_texto(a_entero(total) - suma_nacional[per])
        resultado.append(";".join([nacional, ccaa, prov, cat, per, total]))

    with open(salida, "w", encoding="utf-8-sig", newline="") as f:
        f.write("\r\n".join([cabecera] + resultado) + "\r\n")

    print("Filas de datos:", len(resultado))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])