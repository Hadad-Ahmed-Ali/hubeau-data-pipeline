"""
Module de chargement des données Hub'Eau vers BigQuery.
"""

from google.cloud import bigquery


RESULTATS_DIS_SCHEMA = [
    bigquery.SchemaField("code_departement", "STRING"),
    bigquery.SchemaField("nom_departement", "STRING"),
    bigquery.SchemaField("code_prelevement", "STRING"),
    bigquery.SchemaField("code_parametre", "STRING"),
    bigquery.SchemaField("code_parametre_se", "STRING"),
    bigquery.SchemaField("code_parametre_cas", "STRING"),
    bigquery.SchemaField("libelle_parametre", "STRING"),
    bigquery.SchemaField("libelle_parametre_maj", "STRING"),
    bigquery.SchemaField("libelle_parametre_web", "STRING"),
    bigquery.SchemaField("code_type_parametre", "STRING"),
    bigquery.SchemaField("code_lieu_analyse", "STRING"),
    bigquery.SchemaField("resultat_alphanumerique", "STRING"),
    bigquery.SchemaField("resultat_numerique", "FLOAT64"),
    bigquery.SchemaField("libelle_unite", "STRING"),
    bigquery.SchemaField("code_unite", "STRING"),
    bigquery.SchemaField("limite_qualite_parametre", "STRING"),
    bigquery.SchemaField("reference_qualite_parametre", "STRING"),
    bigquery.SchemaField("code_commune", "STRING"),
    bigquery.SchemaField("nom_commune", "STRING"),
    bigquery.SchemaField("nom_uge", "STRING"),
    bigquery.SchemaField("nom_distributeur", "STRING"),
    bigquery.SchemaField("nom_moa", "STRING"),
    bigquery.SchemaField("date_prelevement", "TIMESTAMP"),
    bigquery.SchemaField("conclusion_conformite_prelevement", "STRING"),
    bigquery.SchemaField("conformite_limites_bact_prelevement", "STRING"),
    bigquery.SchemaField("conformite_limites_pc_prelevement", "STRING"),
    bigquery.SchemaField("conformite_references_bact_prelevement", "STRING"),
    bigquery.SchemaField("conformite_references_pc_prelevement", "STRING"),
    bigquery.SchemaField("reference_analyse", "STRING"),
    bigquery.SchemaField("code_installation_amont", "STRING"),
    bigquery.SchemaField("nom_installation_amont", "STRING"),
    bigquery.SchemaField(
        "reseaux",
        "RECORD",
        mode="REPEATED",
        fields=[
            bigquery.SchemaField("code", "STRING"),
            bigquery.SchemaField("nom", "STRING"),
            bigquery.SchemaField("debit", "STRING"),
        ],
    ),
]
