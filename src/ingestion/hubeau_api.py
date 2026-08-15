"""
Module d'ingestion des données de l'API Hub'Eau.
"""

import requests


def fetch_hubeau_data(code_commune, code_parametre, size=10):
    """
    Récupère les données de l'API Hub'Eau avec pagination.

    Parameters
    ----------
    code_commune : str
        Code INSEE de la commune.
    code_parametre : str
        Code du paramètre analysé.
    size : int, default=10
        Nombre de résultats demandés par page.

    Returns
    -------
    list
        Liste contenant les résultats retournés par l'API.
    """

    url = (
        "https://hubeau.eaufrance.fr/"
        "api/v1/qualite_eau_potable/resultats_dis"
    )

    params = {
        "code_commune": code_commune,
        "code_parametre": code_parametre,
        "page": 1,
        "size": size
    }

    response = requests.get(url, params=params)
    response.raise_for_status()

    data = response.json()

    tous_les_resultats = []
    tous_les_resultats.extend(data["data"])

    next_url = data["next"]

    while next_url:
        response = requests.get(next_url)
        response.raise_for_status()

        data_page = response.json()

        tous_les_resultats.extend(data_page["data"])

        next_url = data_page["next"]

    return tous_les_resultats
