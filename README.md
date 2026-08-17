## 👤 Auteur

**Hadad Ahmed**

En début de carrière et actuellement en recherche d'emploi dans le domaine de la Data, je développe ce projet personnel de Data Analytics Engineering autour des données publiques sur la qualité de l'eau potable issues de l'API Hub'Eau.


# Hub'Eau Data Pipeline

Pipeline de données construit à partir de l'API publique **Hub'Eau — Qualité de l'eau potable**, avec une architecture orientée Data Engineering :

```text
Hub'Eau API
     │
     ▼
   Python : Extraction des données via API, exploration, nettoyage et contrôles légers
     │
     ▼
BigQuery : Stockage des données brutes et Data Warehouse pour les modélisations dbt
     │
     ▼
    dbt : Transformation et modélisation SQL
          Staging → Intermediate → Dimensions / Facts
          Tests et contrôles automatisés de qualité
     │
     ▼
Power BI : Visualisation, analyse et suivi des indicateurs
```

Le projet a pour objectif de mettre en œuvre progressivement une chaîne de données complète : **extraction API, ingestion Python, stockage BigQuery, modélisation dbt, tests, documentation et exploitation analytique**.

---

## État du projet

### Opérationnel

La première grande brique du pipeline est terminée :

```text
API Hub'Eau
     │
     ▼
Extraction Python
     │
     ▼
Pagination automatique
     │
     ▼
DataFrame RAW
     │
     ▼
Chargement BigQuery
     │
     ▼
hubeau_raw.resultats_dis_raw
```

Le pipeline peut être déclenché manuellement avec une seule commande :

```bash
python src/run_ingestion.py
```

### Prochaines étapes

```text
BigQuery
     │
     ▼
    dbt
     │
     ├── staging
     ├── intermediate
     └── marts
          │
          ▼
      DIM / FACT
          │
          ▼
     Analytics / BI
```

---

## Source de données

Le projet utilise l'API publique **Hub'Eau — Qualité de l'eau potable**.

Endpoint utilisé :

```text
qualite_eau_potable/resultats_dis
```

Périmètre actuel :

| Paramètre | Valeur | Description |
|---|---:|---|
| `code_commune` | `45234` | Orléans |
| `code_parametre` | `1340` | Nitrates |

Ce périmètre permet de construire et valider l'architecture sur un jeu de données maîtrisé avant d'envisager une extension à d'autres communes ou paramètres.

---

## Architecture

```text
                    ┌─────────────────────┐
                    │   API Hub'Eau       │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │       Python        │
                    │                     │
                    │ - requêtes HTTP     │
                    │ - pagination        │
                    │ - DataFrame RAW     │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │      BigQuery       │
                    │                     │
                    │     hubeau_raw      │
                    │ resultats_dis_raw   │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │        dbt          │
                    │                     │
                    │ staging             │
                    │ intermediate        │
                    │ marts               │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │     DIM / FACT      │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Analytics / BI    │
                    └─────────────────────┘
```

La couche **API → Python → BigQuery RAW** est actuellement opérationnelle.

Les couches dbt et Analytics seront construites dans les prochaines phases du projet.

---

## Stack technique

### Actuellement utilisée

- **Python**
- **requests**
- **pandas**
- **Google BigQuery**
- **Google Cloud SDK / gcloud**
- **pytest**
- **Git / GitHub**

### Prévue pour les prochaines étapes

- **dbt**
- outil de visualisation / BI à définir

---

## Fonctionnement de l'ingestion

Le point d'entrée du pipeline est :

```text
src/run_ingestion.py
```

Son exécution orchestre automatiquement :

```text
python src/run_ingestion.py
          │
          ▼
fetch_hubeau_data()
          │
          ▼
Pagination Hub'Eau
          │
          ▼
build_raw_dataframe()
          │
          ▼
DataFrame pandas
          │
          ▼
load_to_bigquery()
          │
          ▼
WRITE_TRUNCATE
          │
          ▼
hubeau_raw.resultats_dis_raw
```

Le pipeline est volontairement **déclenché manuellement**.

Dans le cadre de ce projet personnel, aucune exécution horaire ou quotidienne n'est planifiée afin de conserver le contrôle sur les exécutions et d'éviter une orchestration inutile à ce stade.

---

## BigQuery RAW

Les données sont chargées dans :

```text
project-3665c0d5-5952-473b-82e
└── hubeau_raw
    └── resultats_dis_raw
```

Le schéma BigQuery est défini explicitement dans :

```text
src/loading/bigquery_loader.py
```

La table RAW contient actuellement **32 champs**.

Parmi les types importants :

```text
date_prelevement     TIMESTAMP
resultat_numerique   FLOAT
reseaux              RECORD REPEATED
```

Le champ imbriqué `reseaux` est volontairement conservé dans sa structure native afin d'être traité ultérieurement dans la couche dbt.

Il peut déjà être interrogé dans BigQuery avec `UNNEST()`.

---

## Stratégie de chargement

Le pipeline utilise actuellement :

```text
WRITE_TRUNCATE
```

À chaque exécution, le périmètre Hub'Eau est extrait intégralement puis remplace le contenu de :

```text
hubeau_raw.resultats_dis_raw
```

Cette stratégie a été retenue car le volume actuel est faible et qu'une extraction complète reste simple et adaptée au contexte du projet.

Une stratégie incrémentale pourra être étudiée ultérieurement si le périmètre ou le volume augmente.

---

## Authentification Google Cloud

Le pipeline utilise un compte de service dédié :

```text
hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

Aucune clé JSON permanente de compte de service n'est stockée dans le repository.

L'environnement utilise :

```text
Compte Google utilisateur
        │
        ▼
      gcloud
        │
        ▼
Impersonation
        │
        ▼
hubeau-pipeline
        │
        ▼
Application Default Credentials
        │
        ▼
google-cloud-bigquery
```

Cette approche permet au code Python d'utiliser les bibliothèques Google Cloud sans stocker de clé privée permanente dans GitHub.

> Les tokens, codes d'authentification et fichiers locaux de credentials ne doivent jamais être commités dans le repository.

---

# Exécuter le projet

## 1. Cloner le repository

```bash
git clone https://github.com/Hadad-Ahmed-Ali/hubeau-data-pipeline.git
cd hubeau-data-pipeline
```

Si le repository est déjà présent :

```bash
git pull
```

---

## 2. Installer les dépendances

```bash
pip install -r requirements.txt
```

---

## 3. Configurer le projet Google Cloud

```bash
gcloud config set project project-3665c0d5-5952-473b-82e
```

---

## 4. Configurer l'impersonation

```bash
gcloud config set auth/impersonate_service_account \
hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

---

## 5. Configurer les Application Default Credentials

Si les ADC ne sont pas encore disponibles dans l'environnement :

```bash
gcloud auth application-default login \
  --impersonate-service-account=hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

Le processus ouvre une authentification Google.

Les credentials ainsi générés restent locaux et ne doivent pas être ajoutés au repository.

---

## 6. Lancer le pipeline

Depuis la racine du projet :

```bash
python src/run_ingestion.py
```

Une exécution validée du pipeline a produit :

```text
Début de l'ingestion Hub'Eau...
Nombre de résultats récupérés : 311
DataFrame créé : 311 lignes × 32 colonnes
Chargement vers BigQuery...
Table BigQuery chargée : project-3665c0d5-5952-473b-82e.hubeau_raw.resultats_dis_raw
Nombre de lignes dans BigQuery : 311
Pipeline d'ingestion terminé.
```

Le nombre de lignes peut évoluer au fil du temps lorsque de nouvelles analyses sont publiées par Hub'Eau.

---

## Tests

Les tests automatisés utilisent **pytest**.

Ils couvrent actuellement :

- la construction du DataFrame RAW ;
- l'extraction Hub'Eau avec API simulée ;
- la gestion de la pagination ;
- le chargement BigQuery avec client simulé ;
- la destination BigQuery ;
- la stratégie `WRITE_TRUNCATE` ;
- l'attente de la fin du job de chargement.

Lancer l'ensemble des tests :

```bash
python -m pytest tests/ -v
```

État actuel :

```text
4 tests passed
```

Les appels API et BigQuery sont simulés dans les tests concernés afin d'éviter de dépendre des services externes ou d'écrire réellement dans BigQuery.

---

## Validation de la couche RAW

Lors d'une exécution de validation, la table BigQuery contenait :

| Contrôle | Résultat |
|---|---:|
| Nombre de lignes | 311 |
| `reference_analyse` distinctes | 311 |
| Nombre de champs | 32 |
| Date minimale | 2016-01-13 |
| Date maximale | 2026-06-19 |

Ces valeurs correspondent à une exécution donnée et peuvent évoluer avec les données publiées par Hub'Eau.

Le champ `reseaux` a également été validé comme :

```text
RECORD REPEATED
```

et son exploitation avec `UNNEST()` a été testée avec succès.

---

## Structure du repository

```text
hubeau-data-pipeline/
│
├── notebooks/
│   └── 01_exploration_hubeau.ipynb
│
├── src/
│   ├── ingestion/
│   │   └── hubeau_api.py
│   │
│   ├── loading/
│   │   └── bigquery_loader.py
│   │
│   └── run_ingestion.py
│
├── tests/
│   ├── test_hubeau_api.py
│   └── test_bigquery_loader.py
│
├── docs/
│   └── pipeline_hubeau.md
│
├── requirements.txt
├── README.md
└── .gitignore
```

### Responsabilités

| Dossier / fichier | Rôle |
|---|---|
| `notebooks/` | Exploration initiale des données |
| `src/ingestion/` | Extraction Hub'Eau et préparation RAW |
| `src/loading/` | Chargement vers BigQuery |
| `src/run_ingestion.py` | Point d'entrée du pipeline |
| `tests/` | Tests unitaires |
| `docs/` | Documentation technique détaillée |
| `requirements.txt` | Dépendances Python |

---

## Tests et qualité

Le projet applique plusieurs principes visant à rendre le pipeline reproductible et maintenable :

```text
API réelle
   │
   └── remplacée par un mock dans les tests

BigQuery réel
   │
   └── remplacé par un FakeBigQueryClient

Schéma BigQuery
   │
   └── défini explicitement

Pagination
   │
   └── testée automatiquement

Chargement
   │
   └── WRITE_TRUNCATE vérifié automatiquement
```

Cette séparation permet de tester la logique du pipeline sans dépendre systématiquement de services externes.

---

## Documentation technique

La documentation détaillée du pipeline est disponible dans :

```text
docs/pipeline_hubeau.md
```

Elle décrit notamment :

- l'API Hub'Eau ;
- le périmètre d'extraction ;
- la pagination ;
- la préparation du DataFrame RAW ;
- le traitement du champ `reseaux` ;
- le schéma BigQuery ;
- la stratégie `WRITE_TRUNCATE` ;
- l'authentification GCP ;
- l'impersonation du compte de service ;
- les Application Default Credentials ;
- le déclenchement manuel du pipeline ;
- les contrôles BigQuery ;
- les tests unitaires ;
- l'architecture prévue pour dbt.

---

## Roadmap

### Phase 1 — API et Python

- [x] Explorer l'API Hub'Eau
- [x] Identifier le périmètre initial
- [x] Implémenter l'extraction HTTP
- [x] Gérer la pagination
- [x] Construire le DataFrame RAW
- [x] Convertir les dates
- [x] Structurer le code Python
- [x] Ajouter les tests unitaires

### Phase 2 — BigQuery

- [x] Créer `hubeau_raw`
- [x] Définir le schéma BigQuery
- [x] Conserver `reseaux` en `RECORD REPEATED`
- [x] Implémenter `load_to_bigquery()`
- [x] Configurer l'authentification GCP
- [x] Charger `resultats_dis_raw`
- [x] Valider les données dans BigQuery
- [x] Intégrer le chargement dans `run_ingestion.py`
- [x] Tester le loader BigQuery

### Phase 3 — dbt

- [ ] Connecter la couche RAW Hub'Eau à dbt
- [ ] Déclarer la source BigQuery
- [ ] Construire les modèles staging
- [ ] Traiter la structure `reseaux`
- [ ] Construire les modèles intermédiaires
- [ ] Concevoir les dimensions
- [ ] Concevoir les tables de faits
- [ ] Ajouter les tests dbt
- [ ] Documenter la lineage

### Phase 4 — Analytics / BI

- [ ] Définir les KPI
- [ ] Connecter un outil de visualisation
- [ ] Construire les tableaux de bord
- [ ] Documenter les indicateurs

---

## Principes du projet

Le projet suit plusieurs principes Data Engineering :

- séparation entre exploration, ingestion, stockage et transformation ;
- couche RAW proche de la donnée source ;
- schéma BigQuery explicite ;
- conservation des structures imbriquées lorsqu'elles sont pertinentes ;
- transformations métier réservées à dbt ;
- composants Python testables indépendamment ;
- absence de secrets permanents dans Git ;
- déclenchement manuel maîtrisé ;
- documentation évolutive ;
- versionnement Git / GitHub.

---

## Architecture cible

```text
Hub'Eau API
      │
      ▼
Python ingestion
      │
      ▼
BigQuery
      │
      ▼
dbt staging
      │
      ▼
dbt intermediate
      │
      ▼
dbt marts
      │
      ├── dimensions
      └── facts
             │
             ▼
        Power BI : Analytics / BI
```

La couche :

```text
Hub'Eau API → Python → BigQuery RAW
```

est actuellement **opérationnelle et testée**.

La prochaine étape du projet est la construction de la couche **dbt** pour les modélisations SQL décisionnelles.
