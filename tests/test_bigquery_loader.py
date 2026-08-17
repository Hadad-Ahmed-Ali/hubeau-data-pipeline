import pandas as pd

from src.loading.bigquery_loader import load_to_bigquery


def test_load_to_bigquery(monkeypatch):
    """Vérifie le chargement BigQuery sans écrire réellement dans BigQuery."""

    dataframe = pd.DataFrame(
        {
            "code_commune": ["45234"],
            "code_parametre": ["1340"],
            "resultat_numerique": [3.5],
        }
    )

    class FakeLoadJob:
        """Simule un job de chargement BigQuery."""

        def result(self):
            return None

    class FakeTable:
        """Simule une table BigQuery."""

        num_rows = 1

    class FakeBigQueryClient:
        """Simule le client BigQuery."""

        def __init__(self, project=None):
            self.project = project

        def load_table_from_dataframe(
            self,
            dataframe,
            destination,
            job_config=None,
        ):
            return FakeLoadJob()

        def get_table(self, destination):
            return FakeTable()

    monkeypatch.setattr(
        "src.loading.bigquery_loader.bigquery.Client",
        FakeBigQueryClient,
    )

    table = load_to_bigquery(
        dataframe=dataframe,
        project_id="test-project",
        dataset_id="hubeau_raw",
        table_id="resultats_dis_raw",
    )

    assert table.num_rows == 1
