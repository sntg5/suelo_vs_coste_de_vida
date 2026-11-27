# =============================================================================
# 05 · Par de claves RSA para dbt Platform y Power BI
# =============================================================================
# El usuario de Snowflake tiene MFA obligatorio, así que dbt Platform (entorno
# de desarrollo y jobs) y Power BI se conectan con autenticación por par de
# claves.
#
# Se ejecuta en Snowsight como Python Worksheet, con el paquete "cryptography"
# (Anaconda Packages) y el warehouse WH_CURSO. Escribe en la pestaña Output:
#   1. la clave privada cifrada (PKCS#8 en formato PEM, con BEGIN/END);
#   2. la passphrase que la descifra;
#   3. la sentencia ALTER USER que registra la clave pública en Snowflake
#      (se ejecuta con SECURITYADMIN);
#   4. la huella SHA-256 de la clave pública, que se compara con la propiedad
#      RSA_PUBLIC_KEY_FP de DESC USER para comprobar que Snowflake tiene la
#      clave correcta.
# La salida contiene secretos (1 y 2): se guarda en un gestor de contraseñas y
# nunca en el repositorio. Este fichero no contiene ninguna clave.
# Generar la clave dentro de Snowflake es aceptable en una cuenta de prueba; en
# un proyecto real se genera en el equipo del desarrollador o en un gestor de
# secretos y no pasa por el warehouse.
# =============================================================================

import base64
import hashlib
import secrets

import snowflake.snowpark as snowpark
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa


def main(session: snowpark.Session):
    passphrase = secrets.token_urlsafe(18)
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

    # Clave privada en PKCS#8 cifrada con la passphrase (formato que admiten
    # dbt Platform y el conector de Snowflake de Power BI)
    privada = key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.BestAvailableEncryption(passphrase.encode()),
    ).decode()

    # Clave pública: Snowflake la espera sin las líneas BEGIN/END y sin saltos de línea
    publica = key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode()
    cuerpo = "".join(linea for linea in publica.splitlines() if "-----" not in linea)

    # Huella SHA-256 de la clave pública (mismo cálculo que RSA_PUBLIC_KEY_FP)
    publica_der = key.public_key().public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    huella = "SHA256:" + base64.b64encode(hashlib.sha256(publica_der).digest()).decode()

    usuario = session.sql("select current_user()").collect()[0][0]
    alter_user = f"alter user \"{usuario}\" set rsa_public_key = '{cuerpo}';"

    # print() escribe en la pestaña Output, que conserva los saltos de línea del PEM
    print("=" * 70)
    print("1 · CLAVE PRIVADA (dbt Platform y Power BI), con BEGIN/END")
    print("=" * 70)
    print(privada)
    print("=" * 70)
    print("2 · PASSPHRASE")
    print("=" * 70)
    print(passphrase)
    print()
    print("=" * 70)
    print("3 · SENTENCIA PARA REGISTRAR LA CLAVE PÚBLICA (rol SECURITYADMIN)")
    print("=" * 70)
    print(alter_user)
    print()
    print("=" * 70)
    print("4 · HUELLA DE LA CLAVE PÚBLICA (debe coincidir con RSA_PUBLIC_KEY_FP)")
    print("=" * 70)
    print(huella)

    return f"Clave generada para el usuario {usuario}. Resultado en la pestaña Output."


# En un Python Worksheet, Snowsight llama a main(session). En un fichero .py de
# un Workspace el script se ejecuta de arriba abajo, así que se pide la sesión
# activa y se llama a main.
if __name__ == "__main__":
    from snowflake.snowpark.context import get_active_session

    print(main(get_active_session()))
