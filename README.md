# Hub'Eau Data Pipeline

Pipeline **Data Analytics Engineering** construit à partir de l'API publique **Hub'Eau - Qualité de l'eau potable**.

L'objectif du projet est de construire une chaîne de données de bout en bout permettant d'extraire, structurer, fiabiliser et modéliser les données de qualité de l'eau potable afin de préparer leur exploitation analytique dans **Power BI**.

Le périmètre actuel porte sur la commune d'**Orléans** et couvre **12 paramètres physico-chimiques et microbiologiques**, soit **19 923 résultats d'analyse** sur une période allant de **2016 à 2026**.

Le projet met en œuvre une architecture combinant :

**Python · API REST · BigQuery · SQL · dbt · tests automatisés · modélisation décisionnelle · Git/GitHub · Power BI**

---

## 🚀 Vue d'ensemble

```text
Hub'Eau API
     │
     ▼
Python
Extraction multi-paramètres, pagination,
préparation et chargement
     │
     ▼
BigQuery RAW
19 923 résultats · 32 champs
     │
     ▼
dbt Cloud  ◄────────────────────► GitHub
     │                             Versionnement
     ▼
STG
     │
     ▼
ODS
├── Prélèvements
├── Résultats
└── Prélèvements × Réseaux
     │
     ▼
Modèle analytique
├── 5 DIM
├── 2 FACT
└── 1 BRIDGE
     │
     ▼
BigQuery
Modèles dbt matérialisés
     │
     ▼
Power BI
KPI · analyses · tableaux de bord
[prochaine phase]
```

Le pipeline d'ingestion, les couches de transformation dbt et le **modèle analytique DIM / FACT / BRIDGE** sont construits et testés.

La prochaine phase du projet concerne la définition des KPI et la restitution dans Power BI.

---

## 📐 Schéma analytique

La modélisation ne repose pas uniquement sur la structure technique de la source : les **grains métier, clés, cardinalités et relations** ont été étudiés avant la construction des tables analytiques.

Le modèle final distingue notamment :

- les **prélèvements** ;
- les **résultats d'analyse** ;
- les **paramètres mesurés** ;
- les dimensions temporelle, géographique et installation ;
- les **réseaux de distribution** ;
- la relation plusieurs-à-plusieurs entre prélèvements et réseaux.

La documentation dédiée présente les dépendances dbt, le modèle analytique final, les cardinalités et les principales décisions de modélisation :

➡️ **[Consulter le schéma analytique et les décisions de modélisation](docs/schema_analytics/schema_analytics.md)**

Architecture analytique construite :

```text
DIMENSIONS                         TABLES DE FAITS

dim_date ─────────────────────┬──► fact_prelevements
dim_geographie ───────────────┤
dim_installation ─────────────┘

dim_date ─────────────────────┬──► fact_resultats
dim_geographie ───────────────┤
dim_installation ─────────────┤
dim_parametre ────────────────┘


fact_prelevements
        │
        │ 1:N
        ▼
bridge_prelevements_reseaux
        ▲
        │ N:1
        │
dim_reseau
```

La table de pont permet de représenter la relation **N:N entre prélèvements et réseaux** sans dupliquer les lignes des tables de faits.

---

## ✅ État actuel du projet

### Pipeline et modèle analytique construits

- extraction des données depuis l'API Hub'Eau avec **Python** ;
- ingestion de **12 paramètres** de qualité de l'eau ;
- gestion automatique de la pagination ;
- gestion des erreurs temporaires de l'API ;
- construction d'un DataFrame RAW ;
- chargement de **19 923 résultats × 32 champs** dans **Google BigQuery** ;
- conservation de la structure imbriquée `reseaux` dans la RAW ;
- tests Python avec **pytest** ;
- intégration **GitHub ↔ dbt Cloud ↔ BigQuery** ;
- construction et validation de la couche **STAGING** ;
- construction et validation de la couche **ODS / Intermediate** ;
- définition et contrôle des grains métier ;
- traitement des résultats numériques, censurés et non mesurés ;
- structuration des limites et références de qualité ;
- traitement spécifique de la relation prélèvement × réseau ;
- construction et validation de **5 dimensions** ;
- construction et validation de **2 tables de faits** ;
- construction d'une **table de pont** pour la relation prélèvement ↔ réseau ;
- tests dbt génériques, tests de relations et tests SQL personnalisés de grain ;
- documentation de l'exploration, des décisions de modélisation et du schéma analytique.

### 🚧 Prochaine phase

La prochaine étape concerne la couche de restitution :

1. définir les KPI de qualité de l'eau ;
2. définir les mesures analytiques ;
3. connecter **Power BI** aux modèles analytiques BigQuery ;
4. construire les visualisations ;
5. construire le tableau de bord ;
6. documenter les indicateurs.

---

## 👤 Auteur

**Hadad Ahmed**

En début de carrière et actuellement en recherche d'emploi dans le domaine de la Data, je développe ce projet afin de mettre en pratique une architecture orientée **Data Analytics Engineering** sur un cas d'usage réel et des données publiques.

Le projet mobilise notamment :

**Python, API REST, BigQuery, SQL, dbt, Git/GitHub, tests automatisés, qualité des données, modélisation décisionnelle et Power BI.**

---

# Source de données

Le projet utilise l'API publique **Hub'Eau – Qualité de l'eau potable**.

Endpoint utilisé :

```text
qualite_eau_potable/resultats_dis
```

## Périmètre actuel

Le périmètre porte actuellement sur :

```text
Commune : Orléans
Code commune : 45234
Nombre de paramètres : 12
Nombre de résultats : 19 923
Période couverte : 2016 → 2026
```

Les 12 paramètres sélectionnés couvrent des mesures **physico-chimiques et microbiologiques** :

| Code | Paramètre | Unité |
|---:|---|---|
| `1295` | Turbidité | NFU |
| `1301` | Température | °C |
| `1302` | pH | unité pH |
| `1303` | Conductivité | µS/cm |
| `1335` | Ammonium | mg/L |
| `1339` | Nitrites | mg/L |
| `1340` | Nitrates | mg/L |
| `1393` | Fer | µg/L |
| `1394` | Manganèse | µg/L |
| `1398` | Chlore libre | mg(Cl2)/L |
| `1449` | Escherichia coli | n/(100mL) |
| `6455` | Entérocoques | n/(100mL) |

Cette extension multi-paramètres permet de travailler sur des problématiques qui ne seraient pas visibles avec un seul indicateur : unités différentes, résultats censurés, valeurs non mesurées, lieux d'analyse et seuils de qualité variables.

Le périmètre géographique reste volontairement limité à Orléans afin de développer et valider l'architecture analytique avant une éventuelle extension géographique.

---

# Architecture technique

```text
                    ┌─────────────────────┐
                    │   API Hub'Eau       │
                    │  12 paramètres      │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │       Python        │
                    │                     │
                    │ - requêtes HTTP     │
                    │ - pagination        │
                    │ - gestion erreurs   │
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
                    │ - ODS               │
                    │ - dimensions        │
                    │ - facts             │
                    │ - bridge            │
                    │ - tests             │
                    │ - documentation     │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │      BigQuery       │
                    │                     │
                    │ Modèle analytique   │
                    │ DIM / FACT / BRIDGE │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │      Power BI       │
                    │                     │
                    │ - KPI               │
                    │ - analyses          │
                    │ - dashboards        │
                    │                     │
                    │  Prochaine phase    │
                    └─────────────────────┘
```

---

# Stack technique

## Utilisée actuellement

- **Python**
- **requests**
- **pandas**
- **Google Cloud Platform**
- **Google BigQuery**
- **Google Cloud SDK / gcloud**
- **SQL**
- **dbt Cloud / dbt Fusion**
- **pytest**
- **Git**
- **GitHub**

## Prévue pour la restitution

- **Power BI**

---

# Ingestion Python

Le point d'entrée du pipeline est :

```text
src/run_ingestion.py
```

L'ingestion parcourt les **12 paramètres sélectionnés**, récupère les différentes pages de résultats puis construit un DataFrame unique avant le chargement dans BigQuery.

```text
python src/run_ingestion.py
          │
          ▼
12 paramètres
          │
          ▼
Requêtes API Hub'Eau
          │
          ▼
Pagination
          │
          ▼
19 923 résultats
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

Dans le cadre de ce projet personnel, aucune exécution horaire ou quotidienne n'est planifiée afin de garder le contrôle sur les traitements et d'éviter une orchestration inutile à ce stade.

La table RAW actuellement utilisée pour la modélisation contient :

```text
19 923 lignes
32 champs
```

---

# Tests Python

Les tests automatisés utilisent **pytest**.

Ils couvrent notamment :

- la construction du DataFrame RAW ;
- l'extraction Hub'Eau avec API simulée ;
- la pagination ;
- le chargement BigQuery avec client simulé ;
- la destination BigQuery ;
- la configuration `WRITE_TRUNCATE` ;
- l'attente de la fin du job de chargement.

Exécution :

```bash
python -m pytest tests/ -v
```

État validé :

```text
4 tests passed
```

---

# BigQuery

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

La table RAW contient **32 champs**.

Parmi les types importants :

```text
date_prelevement     TIMESTAMP
resultat_numerique   FLOAT64
reseaux              ARRAY<STRUCT<...>>
```

Le champ imbriqué `reseaux` est volontairement conservé dans sa structure native dans la couche RAW.

Son éclatement est effectué ultérieurement dans dbt, dans un modèle dédié, afin de ne pas modifier artificiellement le grain des résultats.

---

# Organisation des modèles dans BigQuery

```text
project-3665c0d5-5952-473b-82e
│
├── hubeau_raw
│   └── resultats_dis_raw
│
├── hubeau_stg
│   └── stg_resultats_dis
│
├── hubeau_ods
│   ├── int_prelevements
│   ├── int_resultats
│   └── int_prelevements_reseaux
│
├── hubeau_dim
│   ├── dim_date
│   ├── dim_geographie
│   ├── dim_installation
│   ├── dim_parametre
│   └── dim_reseau
│
└── hubeau_fact
    ├── fact_prelevements
    ├── fact_resultats
    └── bridge_prelevements_reseaux
```

| Couche | Dataset BigQuery | Rôle |
|---|---|---|
| RAW | `hubeau_raw` | Données proches de la source |
| STG | `hubeau_stg` | Conservation et standardisation légère du grain source |
| ODS / Intermediate | `hubeau_ods` | Structuration et fiabilisation des objets métier |
| DIM | `hubeau_dim` | Dimensions du modèle analytique |
| FACT / BRIDGE | `hubeau_fact` | Tables de faits et relations analytiques |

---

# Modélisation dbt

Le projet dbt est intégré directement au repository :

```text
hubeau-data-pipeline/dbt/
```

La modélisation suit la chaîne :

```text
RAW
 │
 ▼
STG
 │
 ├──────────────┬────────────────────┐
 ▼              ▼                    ▼
Prélèvements   Résultats     Prélèvements × Réseaux
       ODS / Intermediate
 │              │                    │
 ▼              ▼                    ▼
DIM            FACT                BRIDGE
```

Les grains métier sont définis explicitement avant la construction des modèles analytiques.

---

## Couche STAGING

### `stg_resultats_dis`

**Grain :**

```text
1 ligne = 1 résultat brut retourné par l'API Hub'Eau
```

Le staging conserve les **32 champs** de la RAW et reste volontairement proche de la source.

Principes :

- conservation du grain source ;
- absence de transformation métier lourde ;
- conservation des identifiants sous forme de chaînes ;
- conservation des valeurs `NULL` ;
- conservation simultanée de `resultat_alphanumerique` et `resultat_numerique` ;
- conservation de `reseaux` sous forme d'`ARRAY`.

Le modèle est matérialisé en **VIEW**.

---

# Couche ODS / Intermediate

La couche ODS structure les données autour de trois objets métier distincts.

## `int_prelevements`

**Grain :**

```text
1 ligne = 1 prélèvement identifié par code_prelevement
```

Le modèle centralise les informations propres au prélèvement, notamment :

- date et heure ;
- commune ;
- installation amont ;
- informations de conformité du prélèvement.

Les informations propres aux résultats des paramètres restent séparées afin de préserver le grain du prélèvement.

Validation :

```text
1 914 prélèvements
```

---

## `int_resultats`

**Grain :**

```text
1 ligne = 1 résultat d'un paramètre donné,
pour un prélèvement donné et un lieu d'analyse donné
```

Sur le périmètre étudié, la combinaison métier :

```text
code_prelevement
+ code_parametre
+ code_lieu_analyse
```

identifie un résultat sans doublon.

Cette propriété est contrôlée par un test dbt dédié.

Le modèle conserve notamment :

- `code_prelevement` ;
- `code_parametre` ;
- `code_lieu_analyse` ;
- `reference_analyse` ;
- résultat alphanumérique ;
- résultat numérique ;
- opérateur et seuil du résultat ;
- limites de qualité ;
- références de qualité.

### Valeurs censurées

Un résultat tel que :

```text
<0,10
```

ne doit pas être interprété comme une mesure numérique exacte égale à zéro.

Le modèle conserve donc conjointement :

```text
resultat_alphanumerique
resultat_numerique
operateur_resultat
seuil_resultat
```

Les valeurs non mesurées telles que :

```text
N.M.
```

sont également conservées sans leur attribuer artificiellement une mesure numérique.

Validation :

```text
19 923 résultats
```

---

## `int_prelevements_reseaux`

**Grain :**

```text
1 ligne = 1 association entre un prélèvement et un réseau
```

Le tableau imbriqué `reseaux` est éclaté dans ce modèle dédié.

Sur le périmètre étudié, les différents résultats d'un même prélèvement présentent la même configuration de codes réseau. La relation est donc modélisée au niveau du prélèvement plutôt qu'au niveau de chaque résultat.

Le modèle conserve uniquement :

```text
code_prelevement
code_reseau
```

Le champ `debit` n'est pas utilisé comme facteur de pondération : son exploration n'a pas permis de l'interpréter de manière suffisamment fiable comme un poids de répartition entre réseaux.

Validation :

```text
5 197 associations prélèvement × réseau
1 914 prélèvements
6 réseaux
```

---

# Dimensions décisionnelles

Le modèle analytique comporte **5 dimensions**.

## `dim_date`

**Grain :**

```text
1 ligne = 1 date calendaire
```

La dimension génère un calendrier continu entre la première et la dernière date de prélèvement et permet les analyses temporelles.

---

## `dim_geographie`

**Grain :**

```text
1 ligne = 1 commune identifiée par code_commune
```

Elle porte notamment :

```text
code_commune
nom_commune
code_departement
nom_departement
```

---

## `dim_installation`

**Grain :**

```text
1 ligne = 1 installation amont identifiée
par code_installation_amont
```

L'exploration a montré que le libellé associé à une installation peut évoluer dans le temps sans changement de son code.

La dimension utilise le code comme clé métier et conserve le libellé observé le plus récemment.

---

## `dim_parametre`

**Grain :**

```text
1 ligne = 1 paramètre identifié par code_parametre
```

Elle décrit les **12 paramètres** du périmètre et contient notamment :

- codes du paramètre ;
- code CAS lorsqu'il est disponible ;
- type de paramètre ;
- libellés ;
- unité.

Les limites et références de qualité ne sont pas intégrées comme attributs fixes de cette dimension : leur exploration a montré qu'elles peuvent varier selon les observations.

---

## `dim_reseau`

**Grain :**

```text
1 ligne = 1 réseau identifié par code_reseau
```

Plusieurs variantes historiques de libellé peuvent être associées à un même code réseau.

La dimension utilise donc `code_reseau` comme clé métier et conserve les différentes variantes de noms observées plutôt que de sélectionner arbitrairement un libellé unique.

Validation :

```text
6 réseaux
```

---

# Tables de faits

Le modèle analytique comporte **2 tables de faits**, correspondant à deux grains métier différents.

## `fact_prelevements`

**Grain :**

```text
1 ligne = 1 prélèvement identifié par code_prelevement
```

La table contient les attributs nécessaires aux analyses :

- temporelles ;
- géographiques ;
- par installation.

Elle porte également les informations de conformité qui concernent le prélèvement dans son ensemble.

Les conserver à ce niveau évite de les dupliquer pour chaque résultat d'analyse.

Validation :

```text
1 914 prélèvements
```

---

## `fact_resultats`

**Grain :**

```text
1 ligne = 1 résultat d'un paramètre donné,
pour un prélèvement donné et un lieu d'analyse donné
```

La table permet l'analyse des mesures selon :

- le paramètre ;
- la date ;
- la commune ;
- l'installation ;
- le lieu d'analyse.

Elle conserve également les différentes représentations du résultat ainsi que les limites et références de qualité applicables à l'observation.

Validation :

```text
19 923 résultats
```

`reference_analyse` est conservée comme information source, mais n'est pas utilisée comme clé du résultat car elle peut être `NULL` et n'est pas unique à ce grain.

---

# Table de pont

## `bridge_prelevements_reseaux`

**Grain :**

```text
1 ligne = 1 association unique entre un prélèvement et un réseau
```

La relation métier entre les prélèvements et les réseaux est une relation **plusieurs-à-plusieurs** :

```text
1 prélèvement → plusieurs réseaux
1 réseau      → plusieurs prélèvements
```

Ajouter directement `code_reseau` à `fact_prelevements` nécessiterait de répéter un même prélèvement et casserait son grain.

La relation est donc matérialisée par :

```text
fact_prelevements
        │
        │ 1:N
        ▼
bridge_prelevements_reseaux
        ▲
        │ N:1
        │
dim_reseau
```

Validation :

```text
5 197 associations prélèvement × réseau
```

Pour une présentation détaillée des relations, cardinalités et choix de modélisation :

➡️ **[Schéma analytique et décisions de modélisation](docs/schema_analytics/schema_analytics.md)**

---

# Tests et qualité des données avec dbt

Les tests dbt sont définis en fonction des **contrats métier** de chaque modèle.

Ils comprennent notamment :

### Tests génériques

```text
not_null
unique
relationships
```

Ils permettent notamment de contrôler :

- les clés métier ;
- les champs structurants ;
- les relations entre dimensions, faits et bridge.

### Tests SQL personnalisés

Des tests singuliers contrôlent les grains composites qui ne peuvent pas être représentés par un simple test `unique` sur une colonne :

```text
test_int_resultats_grain.sql
test_int_prelevements_reseaux_grain.sql
test_fact_resultats_grain.sql
test_bridge_prelevements_reseaux_grain.sql
```

Ils vérifient notamment l'unicité des combinaisons :

```text
code_prelevement
+ code_parametre
+ code_lieu_analyse
```

et :

```text
code_prelevement
+ code_reseau
```

La logique retenue est de tester les **contrats métier importants** plutôt que d'ajouter mécaniquement des tests sur toutes les colonnes.

---

# Documentation de la modélisation

La documentation est organisée afin de séparer **observation, décision et implémentation**.

```text
dbt/docs/
├── exploration_modelisation_dbt.md
└── matrice_colonnes_modelisation_dbt.md

docs/
└── schema_analytics/
    └── schema_analytics.md
```

## Exploration des données

`dbt/docs/exploration_modelisation_dbt.md`

Documente notamment :

- les grains observés ;
- les cardinalités ;
- les valeurs manquantes ;
- les résultats censurés ;
- les unités ;
- les limites et références de qualité ;
- la structure imbriquée `reseaux` ;
- les installations et réseaux.

## Matrice de modélisation

`dbt/docs/matrice_colonnes_modelisation_dbt.md`

Documente les décisions prises pour les **32 champs de la source** :

- conservation ;
- transformation ;
- couche cible ;
- rôle analytique ;
- justification.

## Schéma analytique

➡️ **[Consulter `schema_analytics.md`](docs/schema_analytics/schema_analytics.md)**

Ce document formalise :

- les dépendances de transformation dbt ;
- les grains métier ;
- les clés métier ;
- les relations et cardinalités ;
- les dimensions ;
- les tables de faits ;
- la table de pont ;
- les principales décisions de modélisation.

L'organisation documentaire suit ainsi la logique :

```text
Observation des données
        │
        ▼
Décisions de modélisation
        │
        ▼
Implémentation dbt
        │
        ▼
Modèle analytique documenté
```

---

# Configuration dbt

Le projet dbt est situé dans :

```text
hubeau-data-pipeline/dbt/
```

Le fichier `dbt_project.yml` configure les datasets et matérialisations :

```text
models/staging/       → hubeau_stg  → VIEW
models/intermediate/  → hubeau_ods  → TABLE
models/dimensions/    → hubeau_dim  → TABLE
models/facts/         → hubeau_fact → TABLE
models/bridges/       → hubeau_fact → TABLE
```

La source RAW BigQuery est déclarée dans :

```text
dbt/models/sources.yml
```

et référencée avec :

```sql
{{ source('hubeau_raw', 'resultats_dis_raw') }}
```

Les dépendances entre modèles utilisent :

```sql
{{ ref('nom_du_modele') }}
```

---

# Connexions dbt

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

La connexion BigQuery a été validée avec :

```bash
dbt debug
```

et le projet avec :

```bash
dbt parse
```

Les modèles peuvent ensuite être construits et testés avec :

```bash
dbt build --select nom_du_modele
```

---

# Authentification et permissions

## Ingestion Python

L'ingestion repose sur les **Application Default Credentials (ADC)** de Google Cloud.

Aucune clé JSON permanente du compte de service d'ingestion n'est stockée dans GitHub.

## dbt Cloud

dbt Cloud utilise son propre compte de service BigQuery.

Les droits suivent le principe du **moindre privilège** :

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

dbt peut ainsi lire les données RAW et matérialiser les modèles uniquement dans les datasets prévus pour les transformations.

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

## 2. Installer les dépendances

```bash
pip install -r requirements.txt
```

## 3. Configurer le projet Google Cloud

```bash
gcloud config set project project-3665c0d5-5952-473b-82e
```

## 4. Configurer les Application Default Credentials

L'environnement local doit disposer d'ADC autorisées à charger les données dans le projet BigQuery.

## 5. Lancer le pipeline

```bash
python src/run_ingestion.py
```

---

# Structure du repository

```text
hubeau-data-pipeline/
│
├── notebooks/
│   └── 01_exploration_hubeau.ipynb
│
├── src/
│   ├── ingestion/
│   │   └── hubeau_api.py
│   ├── loading/
│   │   └── bigquery_loader.py
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
│   ├── docs/
│   │   ├── exploration_modelisation_dbt.md
│   │   └── matrice_colonnes_modelisation_dbt.md
│   │
│   ├── tests/
│   │   ├── test_int_resultats_grain.sql
│   │   ├── test_int_prelevements_reseaux_grain.sql
│   │   ├── test_fact_resultats_grain.sql
│   │   └── test_bridge_prelevements_reseaux_grain.sql
│   │
│   └── models/
│       ├── sources.yml
│       │
│       ├── staging/
│       │   ├── stg_resultats_dis.sql
│       │   └── stg_resultats_dis.yml
│       │
│       ├── intermediate/
│       │   ├── int_prelevements.sql
│       │   ├── int_prelevements.yml
│       │   ├── int_resultats.sql
│       │   ├── int_resultats.yml
│       │   ├── int_prelevements_reseaux.sql
│       │   └── int_prelevements_reseaux.yml
│       │
│       ├── dimensions/
│       │   ├── dim_date.sql
│       │   ├── dim_date.yml
│       │   ├── dim_geographie.sql
│       │   ├── dim_geographie.yml
│       │   ├── dim_installation.sql
│       │   ├── dim_installation.yml
│       │   ├── dim_parametre.sql
│       │   ├── dim_parametre.yml
│       │   ├── dim_reseau.sql
│       │   └── dim_reseau.yml
│       │
│       ├── facts/
│       │   ├── fact_prelevements.sql
│       │   ├── fact_prelevements.yml
│       │   ├── fact_resultats.sql
│       │   └── fact_resultats.yml
│       │
│       └── bridges/
│           ├── bridge_prelevements_reseaux.sql
│           └── bridge_prelevements_reseaux.yml
│
├── docs/
│   ├── pipeline_hubeau.md
│   └── schema_analytics/
│       └── schema_analytics.md
│
├── requirements.txt
├── README.md
└── .gitignore
```

---

# Roadmap

## Phase 1 — API et Python

- [x] Explorer l'API Hub'Eau
- [x] Implémenter l'extraction HTTP
- [x] Gérer la pagination
- [x] Structurer le code Python
- [x] Construire le DataFrame RAW
- [x] Ajouter les tests unitaires
- [x] Étendre l'ingestion à 12 paramètres

## Phase 2 — BigQuery RAW

- [x] Définir explicitement le schéma BigQuery
- [x] Conserver `reseaux` dans sa structure imbriquée
- [x] Implémenter le chargement BigQuery
- [x] Configurer l'authentification GCP
- [x] Charger et valider la table RAW
- [x] Tester le loader BigQuery
- [x] Charger les 19 923 résultats du périmètre multi-paramètres

## Phase 3 — Infrastructure dbt

- [x] Intégrer dbt au repository
- [x] Configurer les datasets RAW / STG / ODS / DIM / FACT
- [x] Connecter dbt Cloud à GitHub et BigQuery
- [x] Configurer les permissions
- [x] Déclarer la source RAW
- [x] Valider la connexion et le projet dbt

## Phase 4 — Exploration et modélisation dbt

- [x] Analyser le grain et les 32 champs RAW
- [x] Étudier les cardinalités et valeurs manquantes
- [x] Étudier les résultats censurés et non mesurés
- [x] Étudier les limites et références de qualité
- [x] Étudier la structure imbriquée `reseaux`
- [x] Documenter les décisions de modélisation
- [x] Construire et tester la couche STG
- [x] Construire et tester la couche ODS
- [x] Construire `int_prelevements`
- [x] Construire `int_resultats`
- [x] Construire `int_prelevements_reseaux`
- [x] Construire les 5 dimensions
- [x] Construire `fact_prelevements`
- [x] Construire `fact_resultats`
- [x] Construire `bridge_prelevements_reseaux`
- [x] Ajouter les tests de relations
- [x] Ajouter les tests de grains composites
- [x] Valider le modèle analytique
- [x] Documenter le schéma analytique, les clés et les cardinalités

## Phase 5 — Analytics / Power BI

- [ ] Définir les KPI
- [ ] Définir les mesures analytiques
- [ ] Connecter Power BI à BigQuery
- [ ] Construire les visualisations
- [ ] Construire le tableau de bord
- [ ] Documenter les indicateurs

---

# Principes de modélisation

Le projet suit notamment les principes suivants :

- séparation entre ingestion, stockage, transformation et restitution ;
- couche RAW proche de la donnée source ;
- schéma BigQuery défini explicitement ;
- conservation des structures imbriquées lorsqu'elles ont une valeur métier ;
- transformations métier réalisées dans dbt ;
- séparation physique RAW / STG / ODS / DIM / FACT ;
- définition explicite du grain de chaque modèle ;
- vérification des données avant la définition d'une règle de modélisation ;
- séparation entre prélèvements et résultats d'analyse ;
- conservation du lieu d'analyse dans le grain du résultat lorsque nécessaire ;
- conservation de la sémantique des valeurs censurées ;
- conservation séparée des limites et références de qualité ;
- séparation entre attributs d'entité et attributs de relation ;
- utilisation d'une table de pont pour préserver les grains face à une relation N:N ;
- absence de pondération par le débit réseau sans justification métier démontrée ;
- absence de choix arbitraire lorsqu'un identifiant possède plusieurs libellés ;
- tests ciblés sur les contrats métier importants ;
- tests de relations entre dimensions, faits et bridge ;
- principe du moindre privilège pour les accès BigQuery ;
- composants Python testables indépendamment ;
- absence de secrets permanents dans Git ;
- déclenchement manuel maîtrisé du pipeline ;
- documentation progressive des observations et décisions ;
- versionnement Git / GitHub.

---

# Prochaine étape — Analytics & Power BI

La couche de données destinée à l'analyse est désormais construite :

```text
5 dimensions
     +
2 tables de faits
     +
1 table de pont
     │
     ▼
Modèle analytique BigQuery
     │
     ▼
Power BI
```

La prochaine phase consiste à exploiter ce modèle pour définir des indicateurs de qualité de l'eau et construire le tableau de bord.

Le travail portera notamment sur :

- la définition des KPI pertinents pour les 12 paramètres ;
- l'analyse temporelle des mesures ;
- l'analyse par paramètre ;
- l'exploitation des limites et références de qualité ;
- l'analyse de la conformité des prélèvements ;
- les axes géographiques, installations et réseaux ;
- le traitement analytique des résultats censurés ;
- la conception des mesures Power BI ;
- la construction et la documentation du dashboard final.

La définition des KPI sera réalisée à partir du modèle analytique validé, afin que la couche de restitution exploite des grains et relations déjà contrôlés.

---

## 📚 Documentation complémentaire

- **[Schéma analytique et décisions de modélisation](docs/schema_analytics/schema_analytics.md)**
- **[Exploration de la modélisation dbt](dbt/docs/exploration_modelisation_dbt.md)**
- **[Matrice des décisions de modélisation](dbt/docs/matrice_colonnes_modelisation_dbt.md)**
- **[Documentation générale du pipeline](docs/pipeline_hubeau.md)**
