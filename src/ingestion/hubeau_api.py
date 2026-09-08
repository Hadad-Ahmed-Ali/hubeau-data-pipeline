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
    code_parametre: str | None = None,
    size: int = 1000
) -> list[dict]:
    """
    Récupère les résultats de l'API Hub'Eau avec pagination.

    Parameters
    ----------
    code_commune : str
        Code de la commune à interroger.

    code_parametre : str | None, default=None
        Code du paramètre analysé.
        Si None, tous les paramètres disponibles pour la commune
        sont récupérés.

    size : int, default=1000
        Nombre de résultats demandés par page.

    Returns
    -------
    list[dict]
        Liste contenant tous les résultats récupérés.
    """

    params = {
        "code_commune": code_commune,
        "page": 1,
        "size": size
    }

    # Le filtre sur le paramètre n'est ajouté que s'il est renseigné.
    # Cela permet d'utiliser la même fonction pour un périmètre
    # mono-paramètre ou multi-paramètres.
    if code_parametre is not None:
        params["code_parametre"] = code_parametre

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
