# Documentation technique — Pipeline Hub'Eau

## Introduction

Ce document décrit l'architecture technique et les choix d'implémentation du projet **Hub'Eau Data Pipeline**.

Le projet a pour objectif de construire progressivement un pipeline de données complet à partir des données publiques de qualité de l'eau potable fournies par l'API **Hub'Eau**.

L'architecture générale est organisée en trois grandes parties :

```text
I. INGESTION
API Hub'Eau
     │
     ▼
   Python
     │
     ▼
BigQuery

II. MODÉLISATION
BigQuery
     │
     ▼
    dbt
     │
     ├── STG
     ├── Intermediate / ODS
     ├── DIM
     └── FACT

III. ANALYTICS
DIM / FACT
     │
     ▼
Visualisation / BI
```

Cette séparation permet de distinguer clairement :

- l'acquisition et le stockage des données sources ;
- les transformations et la modélisation décisionnelle ;
- l'exploitation analytique des données.

---

# I — Ingestion : API Hub'Eau → Python → BigQuery RAW

## 1. Présentation de la source

Le projet utilise l'API publique **Hub'Eau — Qualité de l'eau potable** comme source de données.

Le rôle de la couche d'ingestion est de :

1. interroger l'API Hub'Eau ;
2. gérer automatiquement la pagination ;
3. récupérer les observations correspondant au périmètre demandé ;
4. convertir les données JSON en DataFrame pandas ;
5. réaliser une préparation technique minimale ;
6. charger les données dans une couche RAW BigQuery.

L'objectif est de conserver dans BigQuery une représentation aussi proche que possible de la donnée source.

Les transformations analytiques et métier sont volontairement laissées à la couche de transformation avec **dbt**.

---

## 2. Endpoint utilisé

L'extraction utilise l'endpoint :

```text
qualite_eau_potable/resultats_dis
```

L'URL de base est :

```text
https://hubeau.eaufrance.fr/api/v1/qualite_eau_potable/resultats_dis
```

Cet endpoint fournit les résultats des analyses réalisées sur les prélèvements d'eau distribuée.

---

## 3. Périmètre actuel de l'extraction

Pour la première version du pipeline, l'extraction est volontairement limitée à un périmètre simple afin de construire et valider l'ensemble de l'architecture.

Les paramètres actuellement utilisés sont :

| Paramètre | Valeur | Description |
|---|---:|---|
| `code_commune` | `45234` | Orléans |
| `code_parametre` | `1340` | Nitrates |

Une extraction correspond donc conceptuellement à :

```text
resultats_dis
    │
    ├── code_commune = 45234
    │
    └── code_parametre = 1340
```

Ce périmètre n'est cependant pas codé directement dans les fonctions d'extraction.

Les fonctions Python reçoivent notamment :

```python
code_commune
code_parametre
```

comme paramètres.

Le pipeline pourra donc être étendu ultérieurement à d'autres communes ou à d'autres paramètres de qualité de l'eau.

---

## 4. Structure d'une observation

Chaque observation retournée par l'API correspond à un résultat d'analyse.

Les données contiennent plusieurs catégories d'informations.

### 4.1 Identification du prélèvement et de l'analyse

Exemples de champs :

- `code_prelevement`
- `reference_analyse`

Ces identifiants permettent de distinguer les prélèvements et les analyses retournés par l'API.

### 4.2 Informations géographiques

Exemples :

- `code_departement`
- `nom_departement`
- `code_commune`
- `nom_commune`

Ces informations pourront notamment être utilisées lors de la construction des futures dimensions géographiques.

### 4.3 Paramètre analysé

Exemples :

- `code_parametre`
- `code_parametre_se`
- `code_parametre_cas`
- `libelle_parametre`
- `libelle_parametre_maj`
- `libelle_parametre_web`
- `code_type_parametre`

Dans le périmètre actuel :

```text
code_parametre = 1340
```

correspond aux nitrates.

### 4.4 Résultat de l'analyse

Les principaux champs sont notamment :

- `resultat_alphanumerique`
- `resultat_numerique`
- `code_unite`
- `libelle_unite`
- `limite_qualite_parametre`
- `reference_qualite_parametre`

Exemple :

```text
resultat_numerique = 3.5
libelle_unite      = mg/L
```

`resultat_numerique` constitue une mesure qui pourra être utilisée dans la future modélisation analytique.

### 4.5 Informations temporelles

Le champ temporel principal est :

```text
date_prelevement
```

Il représente la date et l'heure du prélèvement.

### 4.6 Acteurs et installations

L'API fournit également des informations telles que :

- `nom_uge`
- `nom_distributeur`
- `nom_moa`
- `code_installation_amont`
- `nom_installation_amont`

Ces informations sont conservées dans la couche RAW et pourront être exploitées lors de la modélisation.

---

## 5. Gestion de la pagination

L'API Hub'Eau ne renvoie pas nécessairement l'ensemble des résultats dans une seule réponse.

Chaque réponse contient notamment :

```text
data
next
```

`data` contient les observations de la page actuelle.

`next` contient l'URL de la page suivante.

Le fonctionnement est donc :

```text
Page 1
  │
  ├── data
  │
  └── next
       │
       ▼
Page 2
  │
  ├── data
  │
  └── next
       │
       ▼
   ...
       │
       ▼
Dernière page
  │
  ├── data
  │
  └── next = None
```

La fonction Python d'extraction suit automatiquement l'URL contenue dans `next` jusqu'à ce que sa valeur soit `None`.

Cette logique permet de récupérer toutes les observations correspondant aux paramètres demandés, indépendamment du nombre de pages retournées par l'API.

Le nombre d'observations n'est donc pas considéré comme une valeur fixe.

De nouvelles analyses peuvent être publiées dans Hub'Eau et faire évoluer le volume récupéré lors d'une future exécution.

---

## 6. Module d'ingestion Python

La logique d'extraction est principalement implémentée dans :

```text
src/ingestion/hubeau_api.py
```

Deux fonctions principales structurent cette partie du pipeline.

### 6.1 `fetch_hubeau_data()`

Cette fonction est responsable de :

- l'appel HTTP vers Hub'Eau ;
- l'envoi des paramètres de recherche ;
- la récupération des observations ;
- la gestion de la pagination ;
- l'agrégation des différentes pages.

Le résultat est une liste de dictionnaires Python.

Conceptuellement :

```text
API Hub'Eau
     │
     ▼
fetch_hubeau_data()
     │
     ├── page 1
     ├── page 2
     ├── ...
     └── dernière page
              │
              ▼
      Liste d'observations
```

### 6.2 `build_raw_dataframe()`

Une fois les observations récupérées, elles sont converties en DataFrame pandas.

```text
Liste de dictionnaires
        │
        ▼
build_raw_dataframe()
        │
        ▼
DataFrame pandas
        │
        ▼
hub_raw
```

La couche Python réalise volontairement peu de transformations.

L'objectif est de conserver une couche RAW proche de la source et de réserver les transformations métier à dbt.

---

## 7. Préparation technique des données

### 7.1 Conversion de `date_prelevement`

Le champ :

```text
date_prelevement
```

est converti vers un type datetime UTC avec pandas.

Les valeurs de l'API utilisent notamment un format de type :

```text
2026-05-11T13:59:00Z
```

Le `Z` indique que l'heure est exprimée en UTC.

Après conversion, la colonne pandas possède le type :

```text
datetime64[ns, UTC]
```

Cette conversion permet ensuite son chargement dans BigQuery sous forme de :

```text
TIMESTAMP
```

---

## 8. Cas particulier du champ `reseaux`

Le champ `reseaux` possède une structure différente des colonnes classiques.

Une observation peut contenir une liste de plusieurs réseaux.

Exemple simplifié :

```python
[
    {
        "code": "045000474",
        "nom": "ORLEANS"
    },
    {
        "code": "045001825",
        "nom": "SAINT JEAN DE LA RUELLE",
        "debit": "100 %"
    }
]
```

La structure est donc :

```text
reseaux
   │
   ▼
 liste
   │
   ├── dictionnaire
   │      ├── code
   │      ├── nom
   │      └── debit
   │
   └── dictionnaire
          ├── code
          ├── nom
          └── debit
```

Ce champ n'est volontairement **pas aplati dans Python**.

Ce choix permet de respecter le principe :

```text
Ingestion
    ↓
Conservation de la structure source
    ↓
BigQuery RAW
    ↓
Transformation avec dbt
```

Dans BigQuery, `reseaux` est stocké sous forme de :

```text
RECORD REPEATED
```

avec les sous-champs :

```text
reseaux
├── code   STRING
├── nom    STRING
└── debit  STRING
```

BigQuery permet ensuite d'exploiter cette structure avec `UNNEST()`.

Exemple :

```sql
SELECT
    reference_analyse,
    code_commune,
    date_prelevement,
    r.code AS code_reseau,
    r.nom AS nom_reseau,
    r.debit AS debit_reseau
FROM `project-3665c0d5-5952-473b-82e.hubeau_raw.resultats_dis_raw`,
UNNEST(reseaux) AS r;
```

Le traitement analytique définitif de cette structure sera réalisé dans la partie dbt.

---

## 9. Couche RAW BigQuery

### 9.1 Dataset

Un dataset dédié aux données brutes a été créé :

```text
hubeau_raw
```

Il se trouve dans le projet GCP :

```text
project-3665c0d5-5952-473b-82e
```

et dans la région :

```text
europe-west1
```

### 9.2 Table RAW

La table principale est :

```text
hubeau_raw.resultats_dis_raw
```

Son identifiant complet est :

```text
project-3665c0d5-5952-473b-82e.hubeau_raw.resultats_dis_raw
```

Cette table contient les données issues de l'endpoint :

```text
qualite_eau_potable/resultats_dis
```

---

## 10. Schéma BigQuery explicite

Le schéma de la table n'est pas laissé entièrement à l'inférence automatique de BigQuery.

Il est défini dans :

```text
src/loading/bigquery_loader.py
```

avec des objets :

```python
bigquery.SchemaField(...)
```

Le schéma contient actuellement **32 champs**.

Parmi les types importants :

```text
date_prelevement      TIMESTAMP   NULLABLE
resultat_numerique    FLOAT       NULLABLE
reseaux               RECORD      REPEATED
```

Le champ `reseaux` possède lui-même les sous-champs :

```text
code     STRING
nom      STRING
debit    STRING
```

L'utilisation d'un schéma explicite permet notamment :

- de contrôler les types BigQuery ;
- de rendre le chargement reproductible ;
- d'éviter de dépendre entièrement de l'inférence automatique ;
- de documenter techniquement la structure attendue de la couche RAW.

---

## 11. Chargement Python → BigQuery

Le chargement est implémenté dans :

```text
src/loading/bigquery_loader.py
```

La fonction principale est :

```python
load_to_bigquery()
```

Elle reçoit le DataFrame RAW puis construit la destination BigQuery :

```text
project_id.dataset_id.table_id
```

Dans le périmètre actuel :

```text
project-3665c0d5-5952-473b-82e
        │
        └── hubeau_raw
                │
                └── resultats_dis_raw
```

Le chargement utilise :

```python
client.load_table_from_dataframe(...)
```

avec un :

```python
bigquery.LoadJobConfig(...)
```

contenant notamment le schéma explicite de la table.

---

## 12. Stratégie de chargement : `WRITE_TRUNCATE`

La première version du pipeline réalise une extraction complète du périmètre demandé.

La stratégie choisie est donc :

```text
WRITE_TRUNCATE
```

À chaque exécution :

```text
Nouvelle extraction complète Hub'Eau
              │
              ▼
       DataFrame RAW
              │
              ▼
       WRITE_TRUNCATE
              │
              ▼
hubeau_raw.resultats_dis_raw
```

Le contenu existant de la table est remplacé par la nouvelle extraction complète.

Ce choix est adapté au périmètre actuel du projet personnel car :

- le volume est faible ;
- l'extraction complète reste simple ;
- le comportement est facilement reproductible ;
- il évite pour le moment la complexité d'un mécanisme incrémental.

Une stratégie incrémentale pourra être étudiée ultérieurement si le périmètre ou le volume de données augmente.

---

## 13. Authentification Google Cloud pour l'ingestion

### 13.1 Compte de service

Un compte de service dédié au pipeline d'ingestion a été créé :

```text
hubeau-pipeline
```

Adresse :

```text
hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

L'objectif est d'éviter que le code du pipeline dépende directement des droits généraux du compte utilisateur.

### 13.2 Absence de clé JSON permanente

La création de clés de compte de service est désactivée dans l'environnement GCP par la règle :

```text
iam.disableServiceAccountKeyCreation
```

Aucune clé JSON de ce compte de service n'est donc stockée dans le repository.

Le pipeline d'ingestion utilise à la place :

```text
Compte Google utilisateur
          │
          ▼
        gcloud
          │
          ▼
Impersonation du compte de service
          │
          ▼
    hubeau-pipeline
          │
          ▼
Application Default Credentials
          │
          ▼
Bibliothèque Python BigQuery
```

---

## 14. Impersonation du compte de service

L'impersonation peut être configurée avec :

```bash
gcloud config set auth/impersonate_service_account \
hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

Le projet GCP actif peut être configuré avec :

```bash
gcloud config set project project-3665c0d5-5952-473b-82e
```

La configuration peut être contrôlée avec :

```bash
gcloud config list
```

---

## 15. Application Default Credentials — ADC

Pour permettre à :

```python
from google.cloud import bigquery

client = bigquery.Client(...)
```

d'utiliser les credentials appropriés, des **Application Default Credentials (ADC)** sont configurés.

Dans l'environnement utilisé pour le développement :

```bash
gcloud auth application-default login \
  --impersonate-service-account=hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

Le client Python peut alors être créé simplement :

```python
from google.cloud import bigquery

client = bigquery.Client(
    project="project-3665c0d5-5952-473b-82e"
)
```

sans stocker de clé JSON dans le code ou dans GitHub.

> Les fichiers locaux de credentials, codes de vérification et éventuels jetons d'accès ne doivent jamais être ajoutés au repository Git.

---

## 16. Vérification de l'accès BigQuery

L'accès au dataset peut être contrôlé depuis la CLI :

```bash
bq ls --project_id=project-3665c0d5-5952-473b-82e
```

L'accès depuis Python peut également être vérifié avec :

```python
from google.cloud import bigquery

PROJECT_ID = "project-3665c0d5-5952-473b-82e"

client = bigquery.Client(project=PROJECT_ID)

dataset = client.get_dataset(
    f"{PROJECT_ID}.hubeau_raw"
)

print("Dataset accessible :", dataset.dataset_id)
print("Location :", dataset.location)
```

Résultat attendu :

```text
Dataset accessible : hubeau_raw
Location : europe-west1
```

---

## 17. Déclenchement du pipeline

Le pipeline n'est actuellement pas exécuté automatiquement selon une fréquence horaire ou quotidienne.

Le déclenchement est volontairement **manuel**.

Ce choix est adapté au contexte du projet :

- il s'agit d'un projet personnel ;
- les données n'ont pas besoin d'être rafraîchies en continu ;
- il permet de maîtriser les exécutions ;
- il évite une orchestration inutile à ce stade ;
- il permet de garder une architecture simple tout en conservant un pipeline automatisable.

Le point d'entrée est :

```text
src/run_ingestion.py
```

Une seule commande permet de lancer l'ensemble de l'ingestion :

```bash
python src/run_ingestion.py
```

Le flux exécuté est :

```text
python src/run_ingestion.py
          │
          ▼
   API Hub'Eau
          │
          ▼
fetch_hubeau_data()
          │
          ▼
Gestion de la pagination
          │
          ▼
Liste d'observations
          │
          ▼
build_raw_dataframe()
          │
          ▼
DataFrame RAW
          │
          ▼
load_to_bigquery()
          │
          ▼
WRITE_TRUNCATE
          │
          ▼
BigQuery
hubeau_raw.resultats_dis_raw
```

---

## 18. Procédure d'exécution du pipeline

### 18.1 Récupérer le repository

```bash
git clone https://github.com/Hadad-Ahmed-Ali/hubeau-data-pipeline.git
cd hubeau-data-pipeline
```

Si le repository est déjà présent :

```bash
git pull
```

### 18.2 Installer les dépendances

```bash
pip install -r requirements.txt
```

### 18.3 Configurer le projet GCP

```bash
gcloud config set project project-3665c0d5-5952-473b-82e
```

### 18.4 Configurer l'impersonation

```bash
gcloud config set auth/impersonate_service_account \
hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

### 18.5 Configurer les ADC

Si nécessaire :

```bash
gcloud auth application-default login \
  --impersonate-service-account=hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

### 18.6 Lancer le pipeline

```bash
python src/run_ingestion.py
```

Lors de la validation du pipeline, une exécution complète a produit :

```text
Début de l'ingestion Hub'Eau...
Nombre de résultats récupérés : 311
DataFrame créé : 311 lignes × 32 colonnes
Chargement vers BigQuery...
Table BigQuery chargée : project-3665c0d5-5952-473b-82e.hubeau_raw.resultats_dis_raw
Nombre de lignes dans BigQuery : 311
Pipeline d'ingestion terminé.
```

Le nombre de lignes peut évoluer au fil du temps puisque la source Hub'Eau peut recevoir de nouvelles analyses.

---

## 19. Contrôles réalisés dans BigQuery

### 19.1 Contrôle du schéma

```text
date_prelevement     TIMESTAMP   NULLABLE
resultat_numerique   FLOAT       NULLABLE
reseaux              RECORD      REPEATED
```

### 19.2 Contrôle du volume et de l'unicité

```sql
SELECT
    COUNT(*) AS nombre_lignes,
    COUNT(DISTINCT reference_analyse) AS nombre_analyses_uniques,
    MIN(date_prelevement) AS date_min,
    MAX(date_prelevement) AS date_max
FROM `project-3665c0d5-5952-473b-82e.hubeau_raw.resultats_dis_raw`;
```

Lors de la validation :

| Indicateur | Valeur |
|---|---|
| Nombre de lignes | 311 |
| Analyses uniques | 311 |
| Date minimale | 2016-01-13 11:24:00 UTC |
| Date maximale | 2026-06-19 10:04:00 UTC |

Ces valeurs correspondent à une exécution donnée et peuvent évoluer.

### 19.3 Contrôle du champ `reseaux`

```sql
SELECT
    reference_analyse,
    code_commune,
    date_prelevement,
    r.code AS code_reseau,
    r.nom AS nom_reseau,
    r.debit AS debit_reseau
FROM `project-3665c0d5-5952-473b-82e.hubeau_raw.resultats_dis_raw`,
UNNEST(reseaux) AS r
LIMIT 20;
```

Le résultat confirme que BigQuery conserve correctement les réseaux sous forme imbriquée et permet de les éclater avec `UNNEST()`.

---

## 20. Tests automatisés Python

Les tests automatisés utilisent **pytest**.

Ils sont actuellement répartis dans :

```text
tests/
├── test_hubeau_api.py
└── test_bigquery_loader.py
```

Les tests permettent de valider le pipeline sans dépendre systématiquement d'un appel réel à Hub'Eau ou d'une écriture réelle dans BigQuery.

### Tests présents

```text
test_bigquery_loader.py::test_load_to_bigquery
test_hubeau_api.py::test_build_raw_dataframe
test_hubeau_api.py::test_fetch_hubeau_data
test_hubeau_api.py::test_fetch_hubeau_data_pagination
```

Ils couvrent notamment :

- la création du DataFrame RAW ;
- la conversion de `date_prelevement` ;
- les appels API simulés ;
- la pagination ;
- la destination BigQuery ;
- `WRITE_TRUNCATE` ;
- l'attente de la fin du job BigQuery ;
- la récupération de la table chargée.

Les dépendances externes sont simulées avec `monkeypatch`.

---

## 21. Exécution des tests

Depuis la racine du repository :

```bash
python -m pytest tests/ -v
```

Lors de la validation de cette version :

```text
4 tests passed
```

---

## 22. État de la partie ingestion

La chaîne suivante est opérationnelle et testée :

```text
Hub'Eau API
     │
     ▼
fetch_hubeau_data()
     │
     ├── appels HTTP
     └── pagination
             │
             ▼
     Liste d'observations
             │
             ▼
build_raw_dataframe()
             │
             ▼
     DataFrame pandas
      32 colonnes
             │
             ▼
load_to_bigquery()
             │
             ├── schéma explicite
             └── WRITE_TRUNCATE
                     │
                     ▼
                  BigQuery
                     │
                     ▼
             hubeau_raw
                     │
                     ▼
           resultats_dis_raw
```

La partie **API Hub'Eau → Python → BigQuery RAW** est donc terminée dans le périmètre actuel du projet.

---

# II — Modélisation : BigQuery RAW → dbt → Data Warehouse

## 23. Objectif de la couche dbt

La deuxième grande partie du pipeline utilise **dbt** pour transformer les données RAW stockées dans BigQuery.

La séparation des responsabilités est la suivante :

```text
Python
  │
  └── acquisition et chargement des données
              │
              ▼
        BigQuery RAW
              │
              ▼
             dbt
              │
              └── transformations analytiques
                  et modélisation décisionnelle
```

dbt est donc responsable de la transformation des données depuis :

```text
hubeau_raw.resultats_dis_raw
```

vers différentes couches destinées à préparer les données pour l'analyse et la visualisation.

---

## 24. Architecture BigQuery pour dbt

Cinq datasets sont utilisés pour séparer les différentes couches du pipeline :

```text
project-3665c0d5-5952-473b-82e
│
├── hubeau_raw
│   └── resultats_dis_raw
│
├── hubeau_stg
│
├── hubeau_ods
│
├── hubeau_dim
│
└── hubeau_fact
```

Leur rôle est le suivant :

| Dataset | Rôle |
|---|---|
| `hubeau_raw` | Données brutes chargées par Python |
| `hubeau_stg` | Nettoyage et standardisation proche de la source |
| `hubeau_ods` | Transformations intermédiaires et préparation des entités |
| `hubeau_dim` | Dimensions du modèle décisionnel |
| `hubeau_fact` | Tables de faits et mesures analytiques |

Tous ces datasets utilisent la région :

```text
europe-west1
```

Cette séparation permet de matérialiser physiquement dans BigQuery les différentes étapes de transformation dbt.

---

## 25. Intégration de dbt dans le repository principal

Le projet dbt est versionné dans le même repository GitHub que le pipeline Python :

```text
hubeau-data-pipeline
```

Le projet dbt se trouve dans le sous-répertoire :

```text
dbt/
```

Dans dbt Cloud, le paramètre :

```text
Project subdirectory
```

est donc configuré avec :

```text
dbt
```

dbt Cloud considère ainsi :

```text
hubeau-data-pipeline/dbt/
```

comme la racine du projet dbt.

Ce choix permet de conserver dans un repository unique :

```text
Extraction Python
        +
Tests
        +
Documentation
        +
Modélisation dbt
```

et donc de présenter l'ensemble du pipeline dans un même projet versionné.

---

## 26. Structure du projet dbt

La structure mise en place est :

```text
dbt/
│
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

Les modèles SQL seront ajoutés progressivement dans les différents dossiers au cours de la modélisation.

---

## 27. Configuration `dbt_project.yml`

Le fichier :

```text
dbt/dbt_project.yml
```

configure le projet dbt.

Configuration actuelle :

```yaml
name: "hubeau_data_pipeline"
version: "1.0.0"
config-version: 2

profile: "default"

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

target-path: "target"

clean-targets:
  - "target"
  - "dbt_packages"

models:
  hubeau_data_pipeline:

    staging:
      +schema: hubeau_stg
      +materialized: view

    intermediate:
      +schema: hubeau_ods
      +materialized: table

    dimensions:
      +schema: hubeau_dim
      +materialized: table

    facts:
      +schema: hubeau_fact
      +materialized: table
```

Cette configuration établit directement la correspondance :

```text
models/staging/
      │
      ▼
hubeau_stg

models/intermediate/
      │
      ▼
hubeau_ods

models/dimensions/
      │
      ▼
hubeau_dim

models/facts/
      │
      ▼
hubeau_fact
```

Les modèles de staging seront matérialisés en **vues**.

Les modèles ODS, dimensions et faits seront initialement matérialisés en **tables**.

Ces choix pourront évoluer si les besoins du projet changent.

---

## 28. Gestion des noms de datasets

dbt applique normalement une logique de génération de schéma qui peut combiner le schéma cible de développement et le schéma personnalisé.

Afin d'utiliser directement les datasets :

```text
hubeau_stg
hubeau_ods
hubeau_dim
hubeau_fact
```

un macro personnalisé est défini dans :

```text
dbt/macros/generate_schema_name.sql
```

Son contenu est :

```sql
{% macro generate_schema_name(custom_schema_name, node) %}

    {% if custom_schema_name is none %}
        {{ return(target.schema) }}
    {% else %}
        {{ return(custom_schema_name) }}
    {% endif %}

{% endmacro %}
```

Ainsi, lorsqu'un modèle possède :

```yaml
+schema: hubeau_stg
```

dbt utilise directement :

```text
hubeau_stg
```

comme dataset cible.

Le dataset personnel de développement :

```text
dbt_dev
```

reste utilisé comme schéma par défaut lorsqu'aucun schéma personnalisé n'est défini.

---

## 29. Déclaration de la source RAW

La table RAW est déclarée dans :

```text
dbt/models/sources.yml
```

Configuration actuelle :

```yaml
version: 2

sources:
  - name: hubeau_raw
    database: project-3665c0d5-5952-473b-82e
    schema: hubeau_raw

    tables:
      - name: resultats_dis_raw
```

Cette déclaration permet aux modèles dbt de référencer la table RAW avec :

```sql
{{ source('hubeau_raw', 'resultats_dis_raw') }}
```

au lieu d'écrire directement son identifiant BigQuery complet.

La correspondance est :

```text
source('hubeau_raw', 'resultats_dis_raw')
                    │
                    ▼
project-3665c0d5-5952-473b-82e
                    │
                    ▼
hubeau_raw
                    │
                    ▼
resultats_dis_raw
```

Le fichier `sources.yml` est placé directement sous :

```text
models/
```

afin de matérialiser clairement la frontière entre la source RAW et les modèles de transformation.

---

## 30. Connexion dbt Cloud → GitHub

Le projet dbt Cloud est connecté au repository :

```text
Hadad-Ahmed-Ali/hubeau-data-pipeline
```

Le sous-répertoire configuré est :

```text
dbt
```

Le flux de versionnement est donc :

```text
GitHub
hubeau-data-pipeline
        │
        ▼
dbt Cloud / Studio
        │
        ▼
dbt/
```

Lorsqu'une modification est effectuée directement sur GitHub, dbt Studio permet de récupérer la dernière version du repository avec :

```text
Pull from remote
```

Cette opération joue le rôle d'une synchronisation avec les changements présents sur le repository distant.

---

## 31. Connexion dbt Cloud → BigQuery

dbt Cloud est connecté au projet :

```text
project-3665c0d5-5952-473b-82e
```

avec :

```text
Location : europe-west1
```

L'environnement de développement utilise notamment :

```text
Dataset     : dbt_dev
Target name : default
Threads     : 3
```

La connexion dbt et l'ingestion Python utilisent des mécanismes d'authentification distincts.

Le compte de service utilisé pour l'ingestion Python reste :

```text
hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

dbt Cloud utilise quant à lui le compte de service configuré dans sa connexion BigQuery.

Cette séparation permet de distinguer :

```text
Python
   │
   └── écrit dans hubeau_raw

dbt
   │
   ├── lit hubeau_raw
   └── construit les couches STG / ODS / DIM / FACT
```

---

## 32. Permissions BigQuery de dbt

Le compte de service utilisé par dbt dispose des permissions nécessaires au fonctionnement du pipeline de transformation.

Au niveau du projet GCP :

```text
BigQuery Job User
BigQuery Read Session User
```

Le rôle :

```text
BigQuery Job User
```

permet notamment à dbt d'exécuter des jobs BigQuery.

Le rôle :

```text
BigQuery Read Session User
```

est nécessaire à l'environnement dbt Fusion utilisé par dbt Studio pour accéder à BigQuery via la BigQuery Storage API.

Les permissions sur les datasets suivent le principe du moindre privilège :

```text
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

Ainsi :

- dbt peut lire les données RAW ;
- dbt n'a pas besoin de modifier la couche RAW ;
- dbt peut créer et mettre à jour ses modèles dans les datasets de transformation.

Cette séparation protège la frontière entre ingestion et transformation.

---

## 33. Validation de la connexion dbt → BigQuery

La connexion a été vérifiée dans dbt Studio avec :

```bash
dbt debug
```

La configuration reconnue par dbt est notamment :

```text
database : project-3665c0d5-5952-473b-82e
schema   : dbt_dev
priority : interactive
method   : service-account-json
location : europe-west1
```

Lors du premier test, la connexion échouait car dbt Fusion nécessitait le rôle :

```text
BigQuery Read Session User
```

Après ajout de ce rôle au compte de service dbt, le test a abouti :

```text
connection test: OK
All checks passed!
```

Cette validation confirme que dbt Studio peut communiquer correctement avec BigQuery.

---

## 34. Validation du projet dbt

Après déclaration de la source RAW, le projet a été vérifié avec :

```bash
dbt parse
```

Le parsing s'est terminé sans erreur.

Un avertissement :

```text
UnusedResourceConfigPath
```

est actuellement présent pour :

```text
models.hubeau_data_pipeline.staging
models.hubeau_data_pipeline.intermediate
models.hubeau_data_pipeline.dimensions
models.hubeau_data_pipeline.facts
```

Cet avertissement est attendu à ce stade.

Les quatre chemins sont déjà configurés dans :

```text
dbt_project.yml
```

mais aucun modèle SQL n'a encore été créé dans ces dossiers.

Ils seront progressivement utilisés lors de la construction des modèles.

---

## 35. Architecture de transformation cible

L'architecture dbt retenue est :

```text
hubeau_raw.resultats_dis_raw
              │
              ▼
          STAGING
              │
              ▼
        hubeau_stg
              │
              ▼
      INTERMEDIATE / ODS
              │
              ▼
        hubeau_ods
              │
              ▼
     MODÈLE DÉCISIONNEL
          │       │
          ▼       ▼
    hubeau_dim  hubeau_fact
          │       │
          └───┬───┘
              ▼
          Analytics
```

### STG

La couche staging sera destinée aux transformations simples et proches de la source, par exemple :

- sélection des colonnes utiles ;
- renommage et standardisation ;
- contrôle ou harmonisation des types ;
- normalisation simple de certaines valeurs.

La logique métier complexe n'a pas vocation à être placée dans cette couche.

### Intermediate / ODS

La couche intermédiaire permettra de :

- restructurer les données ;
- préparer les entités métier ;
- gérer certaines transformations plus complexes ;
- préparer les données nécessaires au modèle décisionnel.

### DIM

Les dimensions permettront de représenter les axes d'analyse retenus après étude des données.

### FACT

Les tables de faits porteront les mesures et événements nécessaires aux analyses et futurs KPI.

Le grain précis des modèles DIM et FACT n'est volontairement pas défini avant l'analyse détaillée des données RAW.

---

## 36. Prochaine étape : conception de la modélisation

L'infrastructure dbt est maintenant opérationnelle.

La prochaine étape ne consiste plus à configurer les connexions, mais à **concevoir les modèles de données**.

Le travail commencera par l'analyse des 32 champs de :

```text
hubeau_raw.resultats_dis_raw
```

afin de déterminer notamment :

1. le grain des données ;
2. les colonnes pertinentes pour l'analyse ;
3. les éventuels renommages ou standardisations ;
4. le rôle de chaque champ ;
5. le traitement du champ imbriqué `reseaux` ;
6. les entités pouvant devenir des dimensions ;
7. les mesures pouvant alimenter une table de faits ;
8. les futurs besoins en KPI et datavisualisation.

La conception suivra donc le principe :

```text
Compréhension de la donnée RAW
          │
          ▼
Définition du grain
          │
          ▼
Conception STG
          │
          ▼
Conception ODS
          │
          ▼
Conception DIM / FACT
          │
          ▼
Définition des KPI
          │
          ▼
Datavisualisation
```

Cette réflexion sera réalisée avant l'écriture des modèles SQL afin que la structure décisionnelle soit guidée par les futurs usages analytiques plutôt que par une simple reproduction de la source.

---

## 37. Traitement futur de `reseaux`

La structure :

```text
reseaux RECORD REPEATED
```

reste volontairement conservée dans la RAW.

Une piste naturelle consiste à utiliser :

```sql
UNNEST(reseaux)
```

pour représenter les relations entre analyses et réseaux.

Cependant, le modèle définitif n'est pas encore arrêté.

Le traitement sera choisi après analyse du grain des données et des besoins analytiques afin d'éviter de modifier involontairement le niveau de granularité des analyses.

---

## 38. Tests dbt

> **Statut : à construire avec les modèles.**

Les tests pourront notamment couvrir :

- `not_null` ;
- `unique` ;
- `relationships` ;
- `accepted_values` lorsque pertinent ;
- des tests métier spécifiques.

Les tests seront définis en fonction du grain et des contraintes réelles de chaque modèle.

---

# III — Analytics : dbt → Visualisation

## 39. Objectif

La dernière partie du projet consistera à exploiter les modèles décisionnels construits avec dbt dans un outil de visualisation.

L'architecture cible est :

```text
API Hub'Eau
      │
      ▼
Python
      │
      ▼
BigQuery
      │
      ▼
dbt
      │
      ├── STG
      ├── ODS
      ├── DIM
      └── FACT
            │
            ▼
      Visualisation / BI
```

---

## 40. KPI et visualisations

> **Statut : à définir après conception du modèle décisionnel.**

Les KPI ne seront pas définis indépendamment de la modélisation.

La réflexion sur STG, ODS, DIM et FACT devra permettre de préparer les colonnes et les grains nécessaires à leur calcul.

Cette section documentera progressivement :

- les indicateurs retenus ;
- leur définition métier ;
- leurs règles de calcul ;
- les tables utilisées ;
- les dimensions d'analyse ;
- les visualisations construites.

---

# IV — Structure actuelle du repository

La structure principale du repository est désormais :

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

Les responsabilités sont séparées ainsi :

| Élément | Responsabilité |
|---|---|
| `notebooks/` | Exploration et compréhension initiale des données |
| `src/ingestion/` | Extraction Hub'Eau et préparation RAW |
| `src/loading/` | Chargement vers BigQuery |
| `src/run_ingestion.py` | Point d'entrée du pipeline d'ingestion |
| `tests/` | Tests automatisés Python |
| `dbt/models/sources.yml` | Déclaration des sources RAW |
| `dbt/models/staging/` | Modèles STG |
| `dbt/models/intermediate/` | Modèles intermédiaires / ODS |
| `dbt/models/dimensions/` | Dimensions |
| `dbt/models/facts/` | Tables de faits |
| `dbt/macros/` | Macros dbt personnalisées |
| `docs/` | Documentation technique |
| `README.md` | Présentation générale du projet |

---

# V — Roadmap technique

## Phase 1 — Exploration et ingestion Python

- [x] Étudier l'API Hub'Eau
- [x] Tester l'endpoint `resultats_dis`
- [x] Comprendre la structure JSON
- [x] Identifier la structure imbriquée `reseaux`
- [x] Implémenter la pagination
- [x] Construire le DataFrame RAW
- [x] Convertir `date_prelevement`
- [x] Structurer le code Python
- [x] Ajouter les tests unitaires de l'API
- [x] Documenter la source

---

## Phase 2 — BigQuery

- [x] Créer le dataset `hubeau_raw`
- [x] Définir un schéma BigQuery explicite
- [x] Conserver `reseaux` en `RECORD REPEATED`
- [x] Créer le loader Python BigQuery
- [x] Utiliser `WRITE_TRUNCATE`
- [x] Configurer le compte de service `hubeau-pipeline`
- [x] Configurer l'impersonation
- [x] Configurer les Application Default Credentials
- [x] Tester l'accès BigQuery depuis Python
- [x] Charger `resultats_dis_raw`
- [x] Vérifier le schéma BigQuery
- [x] Vérifier la volumétrie et l'unicité
- [x] Tester `UNNEST(reseaux)`
- [x] Intégrer le chargement dans `run_ingestion.py`
- [x] Ajouter le test unitaire du loader BigQuery
- [x] Valider le pipeline complet avec une seule commande

---

## Phase 3 — Infrastructure dbt

- [x] Intégrer le projet dbt au repository `hubeau-data-pipeline`
- [x] Configurer `dbt/` comme sous-répertoire du projet dbt Cloud
- [x] Créer le dataset `hubeau_stg`
- [x] Créer le dataset `hubeau_ods`
- [x] Créer le dataset `hubeau_dim`
- [x] Créer le dataset `hubeau_fact`
- [x] Configurer `dbt_project.yml`
- [x] Configurer `generate_schema_name.sql`
- [x] Connecter dbt Cloud au projet BigQuery Hub'Eau
- [x] Configurer les permissions IAM nécessaires à dbt
- [x] Configurer les credentials de développement
- [x] Valider la connexion avec `dbt debug`
- [x] Déclarer `hubeau_raw.resultats_dis_raw` dans `sources.yml`
- [x] Valider le projet avec `dbt parse`

---

## Phase 4 — Modélisation dbt

- [ ] Analyser le grain et les 32 colonnes RAW
- [ ] Concevoir la couche staging
- [ ] Construire les modèles STG
- [ ] Concevoir la couche intermédiaire / ODS
- [ ] Construire les modèles ODS
- [ ] Définir le traitement de `reseaux`
- [ ] Identifier les dimensions analytiques
- [ ] Concevoir les dimensions
- [ ] Identifier les mesures et événements
- [ ] Concevoir la ou les tables de faits
- [ ] Ajouter les tests dbt
- [ ] Documenter les modèles
- [ ] Valider les dépendances et la lineage dbt

---

## Phase 5 — Analytics / BI

- [ ] Définir les KPI à partir du modèle décisionnel
- [ ] Définir les dimensions d'analyse
- [ ] Choisir / connecter l'outil de visualisation
- [ ] Construire les tableaux de bord
- [ ] Documenter les indicateurs

---

# VI — Principes techniques du projet

Le projet est construit autour de plusieurs principes Data Engineering.

1. **Séparer exploration et code de production**

   Les notebooks servent à comprendre les données tandis que la logique réutilisable est placée dans `src/`.

2. **Conserver une couche RAW proche de la source**

   Les transformations Python sont volontairement limitées.

3. **Préserver les structures utiles**

   Le champ `reseaux` reste imbriqué dans BigQuery plutôt que d'être transformé prématurément.

4. **Séparer ingestion et transformation**

   Python est responsable de l'acquisition et du chargement ; dbt est responsable des transformations analytiques.

5. **Séparer physiquement les couches de données**

   RAW, STG, ODS, DIM et FACT disposent de datasets BigQuery distincts.

6. **Utiliser un schéma de stockage explicite**

   Les types BigQuery RAW sont définis dans le code du loader.

7. **Appliquer le principe du moindre privilège**

   dbt dispose d'un accès en lecture à la RAW et d'un accès en écriture aux datasets qu'il doit construire.

8. **Tester les composants indépendamment**

   Les appels HTTP et BigQuery sont simulés dans les tests Python.

9. **Éviter les secrets permanents dans Git**

   Aucun secret nécessaire à l'ingestion Python n'est versionné dans le repository.

10. **Maîtriser le déclenchement du pipeline**

    Le rafraîchissement de la RAW est actuellement manuel et réalisé uniquement lorsque nécessaire.

11. **Centraliser le projet dans un repository**

    Python, tests, dbt et documentation sont versionnés dans `hubeau-data-pipeline`.

12. **Concevoir avant de transformer**

    Le grain, les entités, les dimensions, les faits et les futurs KPI sont réfléchis avant l'écriture des modèles SQL.

13. **Documenter les choix techniques**

    La documentation évolue avec le pipeline afin de refléter l'architecture réellement implémentée.

---

# VII — État actuel du pipeline

Deux grandes étapes techniques sont désormais terminées :

```text
┌────────────────────────────────────────────────────────────┐
│                    INGESTION — TERMINÉE                    │
│                                                            │
│  API Hub'Eau                                               │
│       │                                                    │
│       ▼                                                    │
│  Extraction Python                                         │
│       │                                                    │
│       ▼                                                    │
│  Pagination                                                │
│       │                                                    │
│       ▼                                                    │
│  DataFrame RAW                                             │
│       │                                                    │
│       ▼                                                    │
│  Schéma BigQuery explicite                                 │
│       │                                                    │
│       ▼                                                    │
│  WRITE_TRUNCATE                                            │
│       │                                                    │
│       ▼                                                    │
│  hubeau_raw.resultats_dis_raw                              │
└────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────┐
│               INFRASTRUCTURE DBT — TERMINÉE                │
│                                                            │
│  GitHub hubeau-data-pipeline                               │
│       │                                                    │
│       ▼                                                    │
│  dbt Cloud / Studio                                        │
│       │                                                    │
│       ├── dbt_project.yml                                  │
│       ├── generate_schema_name.sql                         │
│       ├── sources.yml                                      │
│       ├── dbt debug : OK                                   │
│       └── dbt parse : OK                                   │
│                                                            │
│  BigQuery                                                  │
│       ├── hubeau_stg                                       │
│       ├── hubeau_ods                                       │
│       ├── hubeau_dim                                       │
│       └── hubeau_fact                                      │
└────────────────────────────────────────────────────────────┘
                              │
                              ▼
                       PROCHAINE ÉTAPE
                              │
                              ▼
                  MODÉLISATION DÉCISIONNELLE
                              │
                    ┌─────────┼─────────┐
                    ▼         ▼         ▼
                   STG       ODS    DIM / FACT
                                        │
                                        ▼
                                      KPI
                                        │
                                        ▼
                                 Visualisation
```

Le pipeline dispose donc désormais d'une chaîne technique fonctionnelle :

```text
Hub'Eau
   ↓
Python
   ↓
BigQuery
   ↓
dbt
```

La prochaine étape consiste à transformer cette infrastructure en **modèle décisionnel exploitable**.

Le travail reprendra par l'analyse détaillée de :

```text
project-3665c0d5-5952-473b-82e.hubeau_raw.resultats_dis_raw
```

afin de concevoir les couches STG, ODS, DIM et FACT en tenant compte dès le départ des futurs besoins en KPI et datavisualisation.
