"""
Point d'entrée du pipeline d'ingestion Hub'Eau.
"""

from ingestion.hubeau_api import (
    fetch_hubeau_data,
    build_raw_dataframe,
)
from loading.bigquery_loader import load_to_bigquery


CODE_COMMUNE = "45234"
CODE_PARAMETRE = "1340"

PROJECT_ID = "project-3665c0d5-5952-473b-82e"
DATASET_ID = "hubeau_raw"
TABLE_ID = "resultats_dis_raw"


def main():
    """Exécute le pipeline d'ingestion Hub'Eau."""

    print("Début de l'ingestion Hub'Eau...")

    observations = fetch_hubeau_data(
        code_commune=CODE_COMMUNE,
        code_parametre=CODE_PARAMETRE,
    )

    print(
        f"Nombre de résultats récupérés : "
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
