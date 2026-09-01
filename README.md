## 👤 Auteur

**Hadad Ahmed**

En début de carrière et actuellement en recherche d'emploi dans le domaine de la Data, je développe cette architecture **orientée Data Analytics Engineering** sur les données de l'**API publique Hub'Eau** relatives à la **qualité de l'eau potable** : **extraction via API, ingestion avec Python, stockage BigQuery et mise en œuvre progressive de la modélisation dbt, des tests, de la documentation et de la visualisation Power BI**.


---

# Hub'Eau Data Pipeline

**Projet en cours de développement**  
> La chaîne **API Hub'Eau → Python → BigQuery RAW → dbt Cloud** est opérationnelle et validée.  
> La prochaine étape est la construction des modèles SQL décisionnels **STG → ODS → DIM / FACT**, puis la définition des KPI et la datavisualisation.

Pipeline de données construit à partir de l'API publique **Hub'Eau - Qualité de l'eau potable**, avec une architecture orientée Data Engineering :

```text
Hub'Eau API
     │
     ▼
Python
Extraction API, pagination, préparation technique
     │
     ▼
BigQuery RAW
hubeau_raw.resultats_dis_raw
     │
     ▼
dbt Cloud
STG → ODS → DIM / FACT
     │
     ▼
Power BI
KPI, analyses et tableaux de bord
```

L'objectif du projet est de mettre en œuvre progressivement une chaîne de données complète : **extraction API, ingestion Python, stockage BigQuery, transformation dbt, tests, documentation et exploitation analytique**.

---

## État du projet

### ✅ Terminé

La couche d'ingestion est opérationnelle :

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

L'infrastructure dbt est également configurée :

```text
GitHub
hubeau-data-pipeline
     │
     ▼
dbt Cloud / Studio
     │
     ├── connexion BigQuery validée
     ├── dbt_project.yml
     ├── generate_schema_name.sql
     ├── sources.yml
     ├── dbt debug : OK
     └── dbt parse : OK
```

### 🚧 Prochaine étape

```text
hubeau_raw.resultats_dis_raw
          │
          ▼
       STAGING
          │
          ▼
         ODS
          │
      ┌───┴───┐
      ▼       ▼
     DIM     FACT
      │       │
      └───┬───┘
          ▼
         KPI
          │
          ▼
      Power BI
```

La prochaine phase consiste à analyser les 32 colonnes RAW, définir le grain des données et concevoir les modèles décisionnels en fonction des futurs besoins analytiques.

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
                    │      dbt Cloud      │
                    │                     │
                    │ - staging           │
                    │ - intermediate / ODS│
                    │ - dimensions        │
                    │ - facts             │
                    │ - tests qualité     │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │      Power BI       │
                    │                     │
                    │ - KPI               │
                    │ - analyses          │
                    │ - dashboards        │
                    └─────────────────────┘
```

---

## Stack technique

### Actuellement utilisée

- **Python**
- **requests**
- **pandas**
- **Google BigQuery**
- **Google Cloud SDK / gcloud**
- **pytest**
- **dbt Cloud / dbt Fusion**
- **Git / GitHub**

### Prévue pour la suite

- **Power BI**

---

## Ingestion Python

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

## BigQuery

Les données RAW sont chargées dans :

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

Le champ imbriqué `reseaux` est volontairement conservé dans sa structure native afin d'être traité dans la couche dbt.

Il a déjà été validé dans BigQuery avec `UNNEST()`.

---

## Architecture BigQuery pour dbt

Les couches de transformation sont séparées dans plusieurs datasets :

```text
project-3665c0d5-5952-473b-82e
│
├── hubeau_raw
│   └── resultats_dis_raw
│
├── hubeau_stg
├── hubeau_ods
├── hubeau_dim
└── hubeau_fact
```

Correspondance prévue :

| Couche dbt | Dataset BigQuery |
|---|---|
| RAW | `hubeau_raw` |
| Staging | `hubeau_stg` |
| Intermediate / ODS | `hubeau_ods` |
| Dimensions | `hubeau_dim` |
| Facts | `hubeau_fact` |

---

## Projet dbt

Le projet dbt est intégré directement au repository :

```text
hubeau-data-pipeline/dbt/
```

Structure actuelle :

```text
dbt/
├── dbt_project.yml
│
├── macros/
│   └── generate_schema_name.sql
│
└── models/
    ├── sources.yml
    ├── staging/
    ├── intermediate/
    ├── dimensions/
    └── facts/
```

Le fichier `dbt_project.yml` configure notamment :

```text
models/staging/       → hubeau_stg
models/intermediate/  → hubeau_ods
models/dimensions/    → hubeau_dim
models/facts/         → hubeau_fact
```

Les modèles staging seront matérialisés en **vues**.

Les modèles intermediate, dimensions et facts seront initialement matérialisés en **tables**.

---

## Source dbt

La RAW BigQuery est déclarée dans :

```text
dbt/models/sources.yml
```

avec :

```yaml
version: 2

sources:
  - name: hubeau_raw
    database: project-3665c0d5-5952-473b-82e
    schema: hubeau_raw

    tables:
      - name: resultats_dis_raw
```

Les futurs modèles pourront donc utiliser :

```sql
{{ source('hubeau_raw', 'resultats_dis_raw') }}
```

---

## Connexions dbt validées

dbt Cloud est connecté :

```text
GitHub
Hadad-Ahmed-Ali/hubeau-data-pipeline
        │
        ▼
dbt Cloud / Studio
        │
        ▼
BigQuery
project-3665c0d5-5952-473b-82e
```

Le projet dbt est situé dans le sous-répertoire :

```text
dbt
```

La connexion BigQuery a été validée avec :

```bash
dbt debug
```

Résultat :

```text
connection test: OK
All checks passed!
```

Le projet a également été validé avec :

```bash
dbt parse
```

Le parsing s'effectue sans erreur.

Un warning `UnusedResourceConfigPath` est actuellement attendu car les dossiers `staging`, `intermediate`, `dimensions` et `facts` ne contiennent pas encore de modèles SQL.

---

## Authentification et permissions

### Ingestion Python

L'ingestion utilise le compte de service :

```text
hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

avec impersonation et **Application Default Credentials**.

Aucune clé JSON permanente de ce compte n'est stockée dans GitHub.

### dbt Cloud

dbt Cloud utilise son propre compte de service BigQuery.

Les droits suivent le principe du moindre privilège :

```text
Projet GCP
├── BigQuery Job User
└── BigQuery Read Session User

hubeau_raw
└── BigQuery Data Viewer

hubeau_stg
└── BigQuery Data Editor

hubeau_ods
└── BigQuery Data Editor

hubeau_dim
└── BigQuery Data Editor

hubeau_fact
└── BigQuery Data Editor
```

Ainsi, dbt peut lire la RAW sans la modifier et écrire uniquement dans les datasets de transformation.

---

# Exécuter l'ingestion

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

## Tests Python

Les tests automatisés utilisent **pytest**.

Ils couvrent actuellement :

- la construction du DataFrame RAW ;
- l'extraction Hub'Eau avec API simulée ;
- la gestion de la pagination ;
- le chargement BigQuery avec client simulé ;
- la destination BigQuery ;
- `WRITE_TRUNCATE` ;
- l'attente de la fin du job de chargement.

Lancer les tests :

```bash
python -m pytest tests/ -v
```

État actuel :

```text
4 tests passed
```

---

## Validation de la couche RAW

Lors d'une exécution de validation :

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
├── dbt/
│   ├── dbt_project.yml
│   │
│   ├── macros/
│   │   └── generate_schema_name.sql
│   │
│   └── models/
│       ├── sources.yml
│       ├── staging/
│       ├── intermediate/
│       ├── dimensions/
│       └── facts/
│
├── docs/
│   └── pipeline_hubeau.md
│
├── requirements.txt
├── README.md
└── .gitignore
```

---

## Documentation technique

La documentation détaillée est disponible dans :

```text
docs/pipeline_hubeau.md
```

Elle décrit notamment :

- l'API Hub'Eau ;
- la pagination ;
- l'ingestion Python ;
- le chargement BigQuery ;
- l'authentification GCP ;
- les tests Python ;
- l'architecture des datasets BigQuery ;
- l'intégration dbt Cloud / GitHub ;
- la configuration `dbt_project.yml` ;
- le macro `generate_schema_name` ;
- la déclaration des sources ;
- les permissions IAM dbt ;
- les validations `dbt debug` et `dbt parse` ;
- l'architecture cible STG / ODS / DIM / FACT.

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

### Phase 2 — BigQuery RAW

- [x] Créer `hubeau_raw`
- [x] Définir le schéma BigQuery
- [x] Conserver `reseaux` en `RECORD REPEATED`
- [x] Implémenter `load_to_bigquery()`
- [x] Configurer l'authentification GCP
- [x] Charger `resultats_dis_raw`
- [x] Valider les données dans BigQuery
- [x] Intégrer le chargement dans `run_ingestion.py`
- [x] Tester le loader BigQuery

### Phase 3 — Infrastructure dbt

- [x] Intégrer dbt au repository `hubeau-data-pipeline`
- [x] Configurer le sous-répertoire `dbt`
- [x] Créer `hubeau_stg`
- [x] Créer `hubeau_ods`
- [x] Créer `hubeau_dim`
- [x] Créer `hubeau_fact`
- [x] Configurer `dbt_project.yml`
- [x] Ajouter `generate_schema_name.sql`
- [x] Connecter dbt Cloud à BigQuery
- [x] Configurer les permissions dbt
- [x] Valider la connexion avec `dbt debug`
- [x] Déclarer `resultats_dis_raw` dans `sources.yml`
- [x] Valider le projet avec `dbt parse`

### Phase 4 — Modélisation décisionnelle dbt

- [ ] Analyser le grain et les 32 colonnes RAW
- [ ] Concevoir les modèles staging
- [ ] Construire la couche STG
- [ ] Concevoir la couche ODS
- [ ] Construire les modèles intermédiaires
- [ ] Définir le traitement de `reseaux`
- [ ] Identifier les dimensions
- [ ] Concevoir les tables DIM
- [ ] Identifier les mesures
- [ ] Concevoir la ou les tables FACT
- [ ] Ajouter les tests dbt
- [ ] Documenter les modèles
- [ ] Valider la lineage dbt

### Phase 5 — Analytics / BI

- [ ] Définir les KPI
- [ ] Définir les dimensions d'analyse
- [ ] Connecter Power BI
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
- séparation physique RAW / STG / ODS / DIM / FACT ;
- principe du moindre privilège pour les accès BigQuery ;
- composants Python testables indépendamment ;
- absence de secrets permanents dans Git ;
- déclenchement manuel maîtrisé ;
- centralisation Python + dbt + documentation dans un même repository ;
- conception du grain et des futurs KPI avant la modélisation décisionnelle ;
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
BigQuery RAW
hubeau_raw
      │
      ▼
dbt
      │
      ▼
hubeau_stg
      │
      ▼
hubeau_ods
      │
   ┌──┴──┐
   ▼     ▼
hubeau_dim
      +
hubeau_fact
      │
      ▼
Power BI
```

Les couches :

```text
API Hub'Eau → Python → BigQuery RAW
```

et :

```text
GitHub → dbt Cloud → BigQuery
```

sont actuellement **opérationnelles et validées**.

La prochaine étape du projet est la **modélisation SQL décisionnelle avec dbt**, en commençant par l'analyse du grain et des 32 colonnes de `hubeau_raw.resultats_dis_raw`.
