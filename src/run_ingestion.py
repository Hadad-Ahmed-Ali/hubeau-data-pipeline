"""
Point d'entrée du pipeline d'ingestion Hub'Eau.
"""

from ingestion.hubeau_api import (
    fetch_hubeau_data,
    build_raw_dataframe,
)
from loading.bigquery_loader import load_to_bigquery


CODE_COMMUNE = "45234"

# Périmètre analytique retenu pour le projet :
# 12 paramètres représentatifs de la qualité de l'eau à Orléans.
CODES_PARAMETRES = [
    "1295",  # Turbidité
    "1301",  # Température
    "1302",  # pH
    "1303",  # Conductivité
    "1335",  # Ammonium
    "1339",  # Nitrites
    "1340",  # Nitrates
    "1393",  # Fer
    "1394",  # Manganèse
    "1398",  # Chlore libre
    "1449",  # Escherichia coli
    "6455",  # Entérocoques
]

PROJECT_ID = "project-3665c0d5-5952-473b-82e"
DATASET_ID = "hubeau_raw"
TABLE_ID = "resultats_dis_raw"


def main():
    """Exécute le pipeline d'ingestion Hub'Eau."""

    print("Début de l'ingestion Hub'Eau...")

    observations = []

    # L'API est interrogée séparément pour chaque paramètre afin de
    # maîtriser explicitement le périmètre analytique chargé dans le RAW.
    for code_parametre in CODES_PARAMETRES:

        observations_parametre = fetch_hubeau_data(
            code_commune=CODE_COMMUNE,
            code_parametre=code_parametre,
        )

        observations.extend(observations_parametre)

        print(
            f"Paramètre {code_parametre} : "
            f"{len(observations_parametre)} résultats récupérés"
        )

    print(
        f"Nombre total de résultats récupérés : "
        f"{len(observations)}"
    )

    hub_raw = build_raw_dataframe(observations)

    print(
        f"DataFrame créé : "
        f"{hub_raw.shape[0]} lignes × "
        f"{hub_raw.shape[1]} colonnes"
    )

    print("Chargement vers BigQuery...")

    table = load_to_bigquery(
        dataframe=hub_raw,
        project_id=PROJECT_ID,
        dataset_id=DATASET_ID,
        table_id=TABLE_ID,
    )

    print(
        f"Table BigQuery chargée : "
        f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"
    )

    print(
        f"Nombre de lignes dans BigQuery : "
        f"{table.num_rows}"
    )

    print("Pipeline d'ingestion terminé.")


if __name__ == "__main__":
    main()
