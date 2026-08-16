import pandas as pd

from src.ingestion.hubeau_api import (
    build_raw_dataframe,
    fetch_hubeau_data
)


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


def test_fetch_hubeau_data(monkeypatch):
    """Vérifie la récupération des données sans appeler réellement l'API."""

    fake_api_response = {
        "data": [
            {
                "code_commune": "45234",
                "code_parametre": "1340",
                "resultat_numerique": 3.5
            }
        ],
        "next": None
    }

    class FakeResponse:
        """Simule une réponse HTTP de requests."""

        def raise_for_status(self):
            pass

        def json(self):
            return fake_api_response

    def fake_get(url, params=None):
        """Remplace temporairement requests.get."""
        return FakeResponse()

    monkeypatch.setattr(
        "src.ingestion.hubeau_api.requests.get",
        fake_get
    )

    observations = fetch_hubeau_data(
        code_commune="45234",
        code_parametre="1340"
    )

    assert isinstance(observations, list)
    assert len(observations) == 1
    assert observations[0]["code_commune"] == "45234"
    assert observations[0]["code_parametre"] == "1340"
    assert observations[0]["resultat_numerique"] == 3.5


def test_fetch_hubeau_data_pagination(monkeypatch):
    """Vérifie que toutes les pages de l'API sont récupérées."""

    first_page = {
        "data": [
            {
                "code_commune": "45234",
                "code_parametre": "1340",
                "reference_analyse": "analyse_001"
            }
        ],
        "next": "https://fake-api.test/page=2"
    }

    second_page = {
        "data": [
            {
                "code_commune": "45234",
                "code_parametre": "1340",
                "reference_analyse": "analyse_002"
            }
        ],
        "next": None
    }

    class FakeResponse:
        """Simule une réponse HTTP."""

        def __init__(self, data):
            self.data = data

        def raise_for_status(self):
            pass

        def json(self):
            return self.data

    def fake_get(url, params=None):
        """Retourne une réponse différente selon la page demandée."""

        if params is not None:
            return FakeResponse(first_page)

        return FakeResponse(second_page)

    monkeypatch.setattr(
        "src.ingestion.hubeau_api.requests.get",
        fake_get
    )

    observations = fetch_hubeau_data(
        code_commune="45234",
        code_parametre="1340"
    )

    assert len(observations) == 2
    assert observations[0]["reference_analyse"] == "analyse_001"
    assert observations[1]["reference_analyse"] == "analyse_002"
