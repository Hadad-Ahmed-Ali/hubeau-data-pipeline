"""
Module d'ingestion des données de l'API Hub'Eau.
"""

import requests
import pandas as pd


BASE_URL = (
    "https://hubeau.eaufrance.fr/api/v1/"
    "qualite_eau_potable/resultats_dis"
)


def fetch_hubeau_data(
    code_commune: str,
    code_parametre: str,
    size: int = 1000
) -> list[dict]:
    """
    Récupère les résultats de l'API Hub'Eau avec pagination.

    Parameters
    ----------
    code_commune : str
        Code de la commune à interroger.

    code_parametre : str
        Code du paramètre analysé.

    size : int, default=1000
        Nombre de résultats demandés par page.

    Returns
    -------
    list[dict]
        Liste contenant tous les résultats récupérés.
    """

    params = {
        "code_commune": code_commune,
        "code_parametre": code_parametre,
        "page": 1,
        "size": size
    }

    response = requests.get(BASE_URL, params=params)
    response.raise_for_status()

    data = response.json()

    all_results = data["data"]

    next_url = data["next"]

    while next_url:
        response = requests.get(next_url)
        response.raise_for_status()

        data_page = response.json()

        all_results.extend(data_page["data"])

        next_url = data_page["next"]

    return all_results


def build_raw_dataframe(
    observations: list[dict]
) -> pd.DataFrame:
    """
    Transforme les observations de l'API en DataFrame RAW.

    Une préparation légère est réalisée sur la colonne
    date_prelevement.
    """

    hub_raw = pd.DataFrame(observations)

    hub_raw["date_prelevement"] = pd.to_datetime(
        hub_raw["date_prelevement"],
        utc=True
    )

    return hub_raw
