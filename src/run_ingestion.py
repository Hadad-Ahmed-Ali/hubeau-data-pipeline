"""
Point d'entrée du pipeline d'ingestion Hub'Eau.
"""

from ingestion.hubeau_api import (
    fetch_hubeau_data,
    build_raw_dataframe
)


CODE_COMMUNE = "45234"
CODE_PARAMETRE = "1340"


def main():
    """Exécute l'ingestion des données Hub'Eau."""

    print("Début de l'ingestion Hub'Eau...")

    observations = fetch_hubeau_data(
        code_commune=CODE_COMMUNE,
        code_parametre=CODE_PARAMETRE
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

    print("Ingestion terminée.")


if __name__ == "__main__":
    main()
