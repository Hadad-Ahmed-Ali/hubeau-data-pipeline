"""
Module d'ingestion des données de l'API Hub'Eau.
"""

import time

import pandas as pd
import requests


BASE_URL = (
    "https://hubeau.eaufrance.fr/api/v1/"
    "qualite_eau_potable/resultats_dis"
)


def get_with_retry(
    url: str,
    params: dict | None = None,
    max_retries: int = 3
) -> requests.Response:
    """
    Effectue une requête GET avec plusieurs tentatives
    en cas d'indisponibilité temporaire de l'API Hub'Eau.

    Une attente progressive est appliquée après chaque erreur 503.
    """

    for tentative in range(1, max_retries + 1):

        response = requests.get(url, params=params)

        # Une erreur 503 correspond à une indisponibilité temporaire
        # du service. Les autres erreurs HTTP sont remontées immédiatement.
        if response.status_code != 503:
            response.raise_for_status()
            return response

        print(
            f"API Hub'Eau temporairement indisponible (503) "
            f"- tentative {tentative}/{max_retries}"
        )

        # Attente progressive : 2 s, puis 4 s, puis 6 s.
        time.sleep(tentative * 2)

    # Si toutes les tentatives ont échoué, on conserve
    # le comportement normal de requests en remontant l'erreur HTTP.
    response.raise_for_status()


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

    response = get_with_retry(BASE_URL, params=params)

    data = response.json()

    all_results = data["data"]
    next_url = data["next"]

    while next_url:
        response = get_with_retry(next_url)

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
