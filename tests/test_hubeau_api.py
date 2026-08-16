import pandas as pd

from src.ingestion.hubeau_api import build_raw_dataframe


def test_build_raw_dataframe():
    """Vérifie la construction du DataFrame RAW."""

    observations = [
        {
            "code_commune": "45234",
            "code_parametre": "1340",
            "date_prelevement": "2026-05-11T13:59:00Z",
            "resultat_numerique": 3.5,
            "reseaux": []
        }
    ]

    hub_raw = build_raw_dataframe(observations)

    assert isinstance(hub_raw, pd.DataFrame)
    assert len(hub_raw) == 1
    assert hub_raw["code_commune"].iloc[0] == "45234"
    assert hub_raw["code_parametre"].iloc[0] == "1340"
    assert pd.api.types.is_datetime64_any_dtype(
        hub_raw["date_prelevement"]
    )
