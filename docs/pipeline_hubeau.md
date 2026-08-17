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
BigQuery RAW

II. MODÉLISATION
BigQuery RAW
     │
     ▼
    dbt
     │
     ├── STG
     ├── Intermediate / ODS
     └── DIM / FACT

III. ANALYTICS
DIM / FACT
     │
     ▼
Visualisation / BI
```

Cette séparation permet de distinguer clairement :

- l'acquisition et le stockage des données sources ;
- les transformations et la modélisation ;
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

Les transformations analytiques et métier sont volontairement laissées à la couche de transformation, principalement avec **dbt**.

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

---

### 4.2 Informations géographiques

Exemples :

- `code_departement`
- `nom_departement`
- `code_commune`
- `nom_commune`

Ces informations pourront notamment être utilisées lors de la construction des futures dimensions géographiques.

---

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

---

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

---

### 4.5 Informations temporelles

Le champ temporel principal est :

```text
date_prelevement
```

Il représente la date et l'heure du prélèvement.

---

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

---

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

Un dataset dédié au projet a été créé dans BigQuery :

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

La couche RAW est volontairement séparée des autres projets de données présents dans le même environnement BigQuery.

---

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

## 13. Authentification Google Cloud

### 13.1 Compte de service

Un compte de service dédié au pipeline a été créé :

```text
hubeau-pipeline
```

Adresse :

```text
hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

L'objectif est d'éviter que le code du pipeline dépende directement des droits généraux du compte utilisateur.

---

### 13.2 Accès au dataset

Le compte de service dispose des permissions nécessaires pour travailler avec le dataset :

```text
hubeau_raw
```

L'accès a notamment été configuré afin de permettre l'écriture des données du pipeline dans la couche RAW.

---

### 13.3 Absence de clé JSON permanente

La création de clés de compte de service est désactivée dans l'environnement GCP par la règle :

```text
iam.disableServiceAccountKeyCreation
```

Aucune clé JSON de compte de service n'est donc stockée dans le repository.

Le pipeline utilise à la place une authentification basée sur :

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

Cette approche évite de conserver une clé privée permanente dans le projet.

---

## 14. Impersonation du compte de service

Le compte utilisateur autorisé peut agir temporairement comme :

```text
hubeau-pipeline
```

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

Une configuration valide doit notamment indiquer :

```text
[auth]
impersonate_service_account = hubeau-pipeline@...

[core]
project = project-3665c0d5-5952-473b-82e
```

---

## 15. Application Default Credentials — ADC

L'authentification `gcloud` utilisée par les commandes CLI et l'authentification utilisée automatiquement par les bibliothèques Python sont deux mécanismes à distinguer.

Pour permettre à :

```python
from google.cloud import bigquery

client = bigquery.Client(...)
```

d'utiliser les credentials appropriés, des **Application Default Credentials (ADC)** sont configurés.

Dans l'environnement utilisé pour le développement, la commande est :

```bash
gcloud auth application-default login \
  --impersonate-service-account=hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

Après authentification, les bibliothèques Google Cloud peuvent récupérer automatiquement ces credentials.

Le client Python peut alors être créé simplement :

```python
from google.cloud import bigquery

client = bigquery.Client(
    project="project-3665c0d5-5952-473b-82e"
)
```

sans stocker de clé JSON dans le code ou dans GitHub.

> Les fichiers locaux de credentials et les éventuels jetons d'accès ne doivent jamais être ajoutés au repository Git.

---

## 16. Vérification de l'accès BigQuery

L'accès au dataset peut être contrôlé depuis la CLI :

```bash
bq ls --project_id=project-3665c0d5-5952-473b-82e
```

Le dataset attendu est :

```text
hubeau_raw
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

### 17.1 Choix d'un déclenchement manuel

Le pipeline n'est actuellement pas exécuté automatiquement selon une fréquence horaire ou quotidienne.

Le déclenchement est volontairement **manuel**.

Ce choix est adapté au contexte du projet :

- il s'agit d'un projet personnel ;
- les données n'ont pas besoin d'être rafraîchies en continu ;
- il permet de maîtriser les exécutions ;
- il évite de mettre en place une orchestration inutile à ce stade ;
- il permet de garder une architecture simple tout en conservant un pipeline automatisable.

Le pipeline pourra ultérieurement être orchestré si le besoin évolue.

---

### 17.2 Point d'entrée unique

Le point d'entrée est :

```text
src/run_ingestion.py
```

Une seule commande permet de lancer l'ensemble de l'ingestion :

```bash
python src/run_ingestion.py
```

Cette commande exécute automatiquement :

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
```

Puis :

```bash
cd hubeau-data-pipeline
```

Si le repository est déjà présent :

```bash
git pull
```

---

### 18.2 Installer les dépendances

```bash
pip install -r requirements.txt
```

---

### 18.3 Configurer le projet GCP

```bash
gcloud config set project project-3665c0d5-5952-473b-82e
```

---

### 18.4 Configurer l'impersonation

```bash
gcloud config set auth/impersonate_service_account \
hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

---

### 18.5 Configurer les Application Default Credentials

Si les ADC ne sont pas déjà disponibles dans l'environnement :

```bash
gcloud auth application-default login \
  --impersonate-service-account=hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

Le processus demande une authentification Google.

Les codes de vérification, tokens d'accès et credentials générés ne doivent jamais être copiés dans le repository.

---

### 18.6 Lancer le pipeline

Depuis la racine du repository :

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

Après le premier chargement complet, plusieurs contrôles ont été réalisés directement dans BigQuery.

### 19.1 Contrôle du schéma

Les types importants ont été vérifiés :

```text
date_prelevement     TIMESTAMP   NULLABLE
resultat_numerique   FLOAT       NULLABLE
reseaux              RECORD      REPEATED
```

---

### 19.2 Contrôle du volume et de l'unicité

La requête suivante permet de contrôler la table RAW :

```sql
SELECT
    COUNT(*) AS nombre_lignes,
    COUNT(DISTINCT reference_analyse) AS nombre_analyses_uniques,
    MIN(date_prelevement) AS date_min,
    MAX(date_prelevement) AS date_max
FROM `project-3665c0d5-5952-473b-82e.hubeau_raw.resultats_dis_raw`;
```

Lors de la validation du pipeline, le résultat obtenu était :

| Indicateur | Valeur |
|---|---|
| Nombre de lignes | 311 |
| Analyses uniques | 311 |
| Date minimale | 2016-01-13 11:24:00 UTC |
| Date maximale | 2026-06-19 10:04:00 UTC |

Ce contrôle a notamment permis de vérifier que le chargement n'avait pas introduit de doublons sur `reference_analyse`.

Ces valeurs correspondent à une exécution donnée et peuvent évoluer lorsque de nouvelles données sont publiées.

---

### 19.3 Contrôle du champ `reseaux`

Le champ imbriqué a également été testé avec :

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

Cette capacité sera utilisée lors de la future modélisation dbt.

---

## 20. Tests automatisés Python

Les tests automatisés utilisent **pytest**.

Ils sont actuellement répartis dans :

```text
tests/
├── test_hubeau_api.py
└── test_bigquery_loader.py
```

L'objectif est de tester le comportement du pipeline sans dépendre systématiquement :

- de la disponibilité de Hub'Eau ;
- d'une connexion Internet ;
- d'une connexion réelle à BigQuery ;
- d'une écriture réelle dans GCP.

---

## 21. Tests de l'ingestion Hub'Eau

Le fichier :

```text
tests/test_hubeau_api.py
```

contient trois tests principaux.

### 21.1 `test_build_raw_dataframe()`

Ce test vérifie notamment :

- que la fonction retourne un DataFrame pandas ;
- que les observations sont correctement présentes ;
- que `code_commune` est conservé ;
- que `code_parametre` est conservé ;
- que `date_prelevement` est converti vers un type datetime.

---

### 21.2 `test_fetch_hubeau_data()`

Ce test vérifie le comportement de l'extraction sans appeler réellement l'API.

L'appel :

```python
requests.get(...)
```

est temporairement remplacé par une réponse simulée avec `monkeypatch`.

Le test ne dépend donc pas de la disponibilité réelle de Hub'Eau.

---

### 21.3 `test_fetch_hubeau_data_pagination()`

Ce test simule plusieurs pages API :

```text
Page 1
   │
   ├── observation 1
   └── next
          │
          ▼
       Page 2
          │
          ├── observation 2
          └── next = None
```

Il vérifie ensuite que les observations de toutes les pages sont correctement regroupées.

---

## 22. Test du chargement BigQuery

Le fichier :

```text
tests/test_bigquery_loader.py
```

teste :

```python
load_to_bigquery()
```

sans écrire réellement dans BigQuery.

Le vrai client :

```python
bigquery.Client
```

est temporairement remplacé par un client simulé.

Le principe est :

```text
pytest
   │
   ▼
load_to_bigquery()
   │
   ▼
FakeBigQueryClient
   │
   ├── FakeLoadJob
   │
   └── FakeTable
   │
   ▼
Assertions
```

Le test vérifie notamment :

- le projet BigQuery utilisé ;
- la destination de la table ;
- l'utilisation de `WRITE_TRUNCATE` ;
- l'attente de la fin du job avec `result()` ;
- la récupération de la bonne table ;
- la valeur retournée par le loader.

Aucune écriture réelle n'est effectuée dans BigQuery pendant ce test.

---

## 23. Exécution des tests

Depuis la racine du repository :

```bash
python -m pytest tests/ -v
```

Lors de la validation de cette version du pipeline :

```text
4 tests passed
```

avec :

```text
test_bigquery_loader.py::test_load_to_bigquery
test_hubeau_api.py::test_build_raw_dataframe
test_hubeau_api.py::test_fetch_hubeau_data
test_hubeau_api.py::test_fetch_hubeau_data_pagination
```

---

## 24. Structure actuelle du repository

À ce stade, la structure principale est :

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

Les responsabilités sont séparées de la manière suivante :

| Élément | Responsabilité |
|---|---|
| `notebooks/` | Exploration et compréhension initiale des données |
| `src/ingestion/` | Extraction Hub'Eau et préparation RAW |
| `src/loading/` | Chargement des données vers BigQuery |
| `src/run_ingestion.py` | Orchestration du pipeline d'ingestion |
| `tests/` | Tests unitaires |
| `docs/` | Documentation technique |
| `requirements.txt` | Dépendances Python |
| `README.md` | Présentation générale et guide de démarrage |
| `.gitignore` | Fichiers exclus du versionnement |

---

## 25. Séparation des responsabilités

Le projet suit volontairement une séparation entre :

```text
EXPLORATION
notebooks/
     │
     ▼
INGESTION
src/ingestion/
     │
     ▼
CHARGEMENT
src/loading/
     │
     ▼
STOCKAGE RAW
BigQuery
     │
     ▼
TRANSFORMATION
dbt
     │
     ▼
ANALYTICS
BI
```

Cette organisation permet notamment :

- de ne pas utiliser le notebook comme code de production ;
- de rendre les fonctions Python réutilisables ;
- de tester les composants indépendamment ;
- de conserver une couche RAW proche de la source ;
- de séparer l'ingestion des transformations métier ;
- de faciliter l'évolution future du pipeline.

---

## 26. État actuel de la partie ingestion

La chaîne suivante est désormais opérationnelle :

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

Le pipeline complet peut être déclenché manuellement avec :

```bash
python src/run_ingestion.py
```

La partie **API Hub'Eau → Python → BigQuery RAW** est donc fonctionnelle et testée.

---

# II — Modélisation : BigQuery RAW → dbt

## 27. Objectif de la couche dbt

La prochaine grande étape consiste à transformer les données RAW stockées dans :

```text
hubeau_raw.resultats_dis_raw
```

avec **dbt**.

Contrairement à la couche Python, dbt sera responsable des transformations analytiques et métier.

Le principe cible est :

```text
BigQuery RAW
     │
     ▼
    dbt
     │
     ├── STG
     │
     ├── Intermediate / ODS
     │
     └── DIM / FACT
```

---

## 28. Principes prévus pour la modélisation

La modélisation devra notamment permettre de :

- nettoyer et standardiser les colonnes ;
- gérer les éventuelles valeurs manquantes ;
- transformer la structure imbriquée `reseaux` ;
- séparer les différentes entités métier ;
- construire des modèles intermédiaires ;
- créer des dimensions ;
- créer une ou plusieurs tables de faits ;
- ajouter des tests de qualité dbt ;
- documenter les modèles et leurs dépendances.

La structure exacte sera définie après analyse de la couche RAW.

---

## 29. Modèles dbt

> **Statut : à construire.**

Cette section sera complétée progressivement pendant le développement des modèles dbt.

Elle documentera notamment :

```text
models/
└── hubeau/
    ├── staging/
    ├── intermediate/
    └── marts/
```

Pour chaque modèle, la documentation précisera :

- son objectif ;
- sa source ;
- son grain ;
- ses transformations principales ;
- ses clés ;
- ses relations avec les autres modèles ;
- les tests associés.

---

## 30. Traitement futur de `reseaux`

La structure :

```text
reseaux RECORD REPEATED
```

est volontairement conservée dans la RAW.

La stratégie de transformation sera définie dans dbt.

Une piste naturelle consistera à exploiter :

```sql
UNNEST(reseaux)
```

afin de construire un modèle spécifique permettant de représenter correctement la relation entre les analyses et les réseaux.

Le choix définitif sera documenté lors de l'implémentation.

---

## 31. Tests dbt

> **Statut : à construire.**

Les tests dbt pourront notamment couvrir :

- `not_null` ;
- `unique` ;
- `relationships` ;
- `accepted_values` lorsque cela est pertinent ;
- des tests métier spécifiques si nécessaire.

Les tests réellement implémentés seront documentés dans cette section au fur et à mesure du développement.

---

# III — Analytics : dbt → Visualisation

## 32. Objectif

La dernière partie du projet consistera à exploiter les modèles analytiques construits avec dbt dans un outil de visualisation.

L'architecture cible est :

```text
API Hub'Eau
      │
      ▼
Python
      │
      ▼
BigQuery RAW
      │
      ▼
dbt
      │
      ▼
DIM / FACT
      │
      ▼
Visualisation / BI
```

---

## 33. Indicateurs et visualisations

> **Statut : à définir.**

Les KPI et visualisations seront définis une fois la modélisation analytique stabilisée.

Cette section documentera notamment :

- les indicateurs retenus ;
- leurs règles de calcul ;
- les tables utilisées ;
- les dimensions d'analyse ;
- les visualisations construites.

---

# IV — Roadmap technique

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

## Phase 2 — BigQuery RAW

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

## Phase 3 — dbt

- [ ] Déclarer la source `hubeau_raw.resultats_dis_raw`
- [ ] Définir l'architecture des modèles Hub'Eau
- [ ] Construire les modèles de staging
- [ ] Construire les modèles intermédiaires / ODS
- [ ] Définir le traitement de `reseaux`
- [ ] Concevoir les dimensions
- [ ] Concevoir les tables de faits
- [ ] Ajouter les tests dbt
- [ ] Documenter les modèles dbt
- [ ] Valider la lineage dbt

---

## Phase 4 — Analytics / BI

- [ ] Définir les KPI
- [ ] Choisir / connecter l'outil de visualisation
- [ ] Construire les tableaux de bord
- [ ] Documenter les indicateurs

---

# V — Principes techniques du projet

Le projet est construit autour de plusieurs principes Data Engineering :

1. **Séparer exploration et code de production**

   Les notebooks servent à comprendre les données tandis que la logique réutilisable est placée dans `src/`.

2. **Conserver une couche RAW proche de la source**

   Les transformations Python sont volontairement limitées.

3. **Préserver les structures utiles**

   Le champ `reseaux` reste imbriqué dans BigQuery plutôt que d'être transformé prématurément.

4. **Séparer ingestion et transformation**

   Python est responsable de l'acquisition et du chargement ; dbt sera responsable de la transformation analytique.

5. **Utiliser un schéma de stockage explicite**

   Les types BigQuery sont définis dans le code du loader.

6. **Tester les composants indépendamment**

   Les appels HTTP et BigQuery sont simulés dans les tests unitaires.

7. **Éviter les secrets permanents dans Git**

   L'accès GCP utilise l'impersonation et les Application Default Credentials plutôt qu'une clé JSON stockée dans le projet.

8. **Maîtriser le déclenchement du pipeline**

   Le rafraîchissement est actuellement manuel et réalisé uniquement lorsque nécessaire.

9. **Versionner le code et la documentation**

   Les évolutions du pipeline sont suivies dans Git / GitHub.

10. **Documenter les choix techniques**

    La documentation évolue avec le pipeline afin de refléter l'architecture réellement implémentée.

---

# VI — État actuel du pipeline

À ce stade, la première grande brique du projet est terminée :

```text
                         TERMINÉ
                            │
                            ▼
┌─────────────────────────────────────────────────────┐
│                                                     │
│  API Hub'Eau                                        │
│       │                                             │
│       ▼                                             │
│  Extraction Python                                  │
│       │                                             │
│       ▼                                             │
│  Pagination                                         │
│       │                                             │
│       ▼                                             │
│  DataFrame RAW                                      │
│       │                                             │
│       ▼                                             │
│  Schéma BigQuery explicite                          │
│       │                                             │
│       ▼                                             │
│  Chargement WRITE_TRUNCATE                          │
│       │                                             │
│       ▼                                             │
│  hubeau_raw.resultats_dis_raw                       │
│                                                     │
└─────────────────────────────────────────────────────┘
                            │
                            ▼
                       PROCHAINE ÉTAPE
                            │
                            ▼
                           dbt
                            │
                  ┌─────────┼─────────┐
                  ▼         ▼         ▼
                 STG   Intermediate  Marts
                                      │
                                      ▼
                                  DIM / FACT
                                      │
                                      ▼
                                Visualisation
```

La prochaine étape du projet consiste donc à démarrer la modélisation des données Hub'Eau avec **dbt**, en prenant comme source la table RAW :

```text
project-3665c0d5-5952-473b-82e.hubeau_raw.resultats_dis_raw
```
