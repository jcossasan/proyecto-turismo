"""
Ingesta de la Encuesta de Ocupación Hotelera (EOH) del INE.

Qué hace, paso a paso:
  1. Descarga los datos de la API pública del INE (tabla 67190: viajeros y
     pernoctaciones por comunidades autónomas y provincias, mensual).
  2. Los convierte en una tabla de pandas (un "DataFrame").
  3. Comprueba que los datos tienen sentido.
  4. Los guarda en un CSV local (data/raw/).
  5. (Opcional) Los carga en BigQuery, si defines las variables de entorno
     BQ_PROJECT y BQ_DATASET.

Uso:
    python ingesta_ine.py --ultimos 12
"""

import argparse
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
import requests

# --- Configuración ---------------------------------------------------------
TABLA_ID = 67190
URL_API = f"https://servicios.ine.es/wstempus/js/ES/DATOS_TABLA/{TABLA_ID}"
SALIDA_CSV = Path("data/raw/eoh_viajeros_pernoctaciones.csv")


# --- 1. Descarga -----------------------------------------------------------
def descargar(n_periodos: int) -> list:
    """Pide a la API del INE los últimos `n_periodos` meses de todas las series."""
    respuesta = requests.get(URL_API, params={"nult": n_periodos}, timeout=60)
    respuesta.raise_for_status()  # si la API falla, se detiene aquí con un error claro
    return respuesta.json()


# --- 2. De JSON a tabla ----------------------------------------------------
def a_dataframe(series: list) -> pd.DataFrame:
    """
    La API devuelve una lista de "series". Cada serie tiene un nombre y una
    lista de datos (fecha + valor). Aquí la aplanamos: una fila por cada dato.
    """
    filas = []
    for serie in series:
        for dato in serie.get("Data", []):
            filas.append(
                {
                    "serie_cod": serie.get("COD"),
                    "serie_nombre": serie.get("Nombre"),
                    "fecha": pd.to_datetime(dato.get("Fecha"), unit="ms", utc=True),
                    "anio": dato.get("Anyo"),
                    "periodo_id": dato.get("FK_Periodo"),
                    "valor": dato.get("Valor"),
                    "secreto": dato.get("Secreto"),
                }
            )

    df = pd.DataFrame(filas)
    # Marca de cuándo se cargó, útil para auditar más adelante.
    # Se guarda CON zona horaria (UTC): así BigQuery crea siempre columnas de tipo
    # TIMESTAMP. Sin zona horaria, la librería puede elegir DATETIME y romper
    # funciones como DATE(fecha, 'Europe/Madrid') en dbt.
    df["cargado_en"] = datetime.now(timezone.utc)
    return df


# --- 3. Comprobaciones básicas de calidad ----------------------------------
def validar(df: pd.DataFrame) -> None:
    """Si algo no cuadra, paramos con un mensaje claro en vez de guardar datos malos."""
    if df.empty:
        sys.exit("ERROR: la API no devolvió datos.")

    if df["valor"].isna().all():
        sys.exit("ERROR: todos los valores vienen vacíos.")

    duplicados = df.duplicated(subset=["serie_cod", "fecha"]).sum()
    if duplicados > 0:
        sys.exit(f"ERROR: hay {duplicados} filas duplicadas (serie + fecha).")

    print(f"OK: {len(df):,} filas, {df['serie_cod'].nunique():,} series.")
    print(f"Rango de fechas: {df['fecha'].min().date()} -> {df['fecha'].max().date()}")


# --- 4. Guardar en CSV -----------------------------------------------------
def guardar_csv(df: pd.DataFrame) -> None:
    SALIDA_CSV.parent.mkdir(parents=True, exist_ok=True)  # crea data/raw/ si no existe
    df.to_csv(SALIDA_CSV, index=False)
    print(f"CSV guardado en {SALIDA_CSV}")


# --- 5. (Opcional) Cargar en BigQuery --------------------------------------
def cargar_en_bigquery(df: pd.DataFrame, proyecto: str, dataset: str) -> None:
    # Se importa aquí para que el script funcione sin BigQuery instalado/configurado.
    from google.cloud import bigquery

    cliente = bigquery.Client(project=proyecto)
    cliente.create_dataset(f"{proyecto}.{dataset}", exists_ok=True)

    tabla = f"{proyecto}.{dataset}.raw_eoh_viajeros_pernoctaciones"
    config = bigquery.LoadJobConfig(write_disposition="WRITE_TRUNCATE")  # sustituye la tabla
    trabajo = cliente.load_table_from_dataframe(df, tabla, job_config=config)
    trabajo.result()  # espera a que termine
    print(f"Cargadas {len(df):,} filas en BigQuery: {tabla}")


# --- Programa principal ----------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(description="Ingesta EOH (INE)")
    parser.add_argument(
        "--ultimos", type=int, default=12, help="Número de meses a descargar (por defecto 12)"
    )
    args = parser.parse_args()

    print(f"Descargando los últimos {args.ultimos} periodos de la tabla {TABLA_ID}...")
    series = descargar(args.ultimos)
    df = a_dataframe(series)
    validar(df)
    guardar_csv(df)

    proyecto = os.getenv("BQ_PROJECT")
    dataset = os.getenv("BQ_DATASET")
    if proyecto and dataset:
        cargar_en_bigquery(df, proyecto, dataset)
    else:
        print("BigQuery no configurado (BQ_PROJECT / BQ_DATASET): se omite la carga.")


if __name__ == "__main__":
    main()
