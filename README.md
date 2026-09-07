# Hub'Eau Data Pipeline

Pipeline Data Analytics Engineering construit à partir de l'API publique **Hub'Eau - Qualité de l'eau potable**.

Le projet met en œuvre une chaîne de données complète allant de l'extraction API, la modélisation décisionnelle jusqu'à la visualisation Power BI :

```text
Hub'Eau API
     │
     ▼
Python
Extraction, pagination, préparation des données
     │
     ▼
BigQuery RAW
hubeau_raw.resultats_dis_raw
     │
     ▼
dbt Cloud
STG → ODS → DIM → FACT
Githu pour les versionnments des modèls
     │
     ▼
Power BI
KPI, analyses et tableaux de bord
```

## État actuel du projet

### ✅ Opérationnel et validé

- extraction des données depuis l'API Hub'Eau avec **Python** ;
- gestion automatique de la pagination ;
- chargement des données RAW dans **Google BigQuery** ;
- tests Python avec **pytest** ;
- intégration **GitHub ↔ dbt Cloud ↔ BigQuery** ;
- couche **STAGING**, avec ses tests et documentations, construite et testée ;
- couche **ODS / Intermediate**, avec ses tests et documentations, construite et testée ;
- traitement spécifique de la structure imbriquée `reseaux` ;
- couche **DIM**, avec ses tests et documentations, construite et testée ;
- tests dbt génériques et test métier personnalisé sur le grain des relations analyse × réseau.

Architecture dbt actuellement disponible :

```text
hubeau_raw
└── resultats_dis_raw
        │
        ▼
hubeau_stg
└── stg_resultats_dis
        │
        ▼
hubeau_ods
├── int_prelevements
├── int_resultats
└── int_analyses_reseaux
        │
        ▼
hubeau_dim
├── dim_date
├── dim_geographie
├── dim_parametre
├── dim_installation
└── dim_reseau
```

### 🚧 Reste à construire

```text
FACT
   │
   ▼
KPI
   │
   ▼
Visualisations Power BI
```

Les prochaines étapes sont donc :

1. concevoir la ou les tables de faits ;
2. définir les mesures et KPI ;
3. mettre en place les relations du modèle analytique final ;
4. connecter Power BI à BigQuery ;
5. construire et documenter les tableaux de bord.

---

## 👤 Auteur

**Hadad Amed**

En début de carrière et actuellement en recherche d'emploi dans le domaine de la Data, je développe ce projet afin de mettre en pratique une architecture orientée **Data Analytics Engineering** combinant :

**Python, API, BigQuery, SQL, dbt, tests, modélisation décisionnelle, qualité des données et Power BI.**

---

# Source de données

Le projet utilise l'API publique **Hub'Eau - Qualité de l'eau potable**.

Endpoint utilisé :

```text
qualite_eau_potable/resultats_dis
```

Périmètre actuel :

| Paramètre | Valeur | Description |
|---|---:|---|
| `code_commune` | `45234` | Orléans |
| `code_parametre` | `1340` | Nitrates |

Ce périmètre volontairement restreint permet de construire et valider l'architecture sur un jeu de données maîtrisé avant une éventuelle extension à d'autres communes ou paramètres.

Lors d'une exécution de validation :

| Contrôle | Résultat |
|---|---:|
| Nombre de lignes RAW | 311 |
| Nombre de champs | 32 |
| `reference_analyse` distinctes | 311 |
| Date minimale | 2016-01-13 |
| Date maximale | 2026-06-19 |

Ces valeurs correspondent à une exécution donnée et peuvent évoluer lorsque de nouvelles analyses sont publiées par Hub'Eau.

---

# Architecture technique

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
                    │ - ODS / intermediate│
                    │ - dimensions        │
                    │ - facts             │
                    │ - tests             │
                    │ - documentation     │
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

Son exécution orchestre :

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

Dans le cadre de ce projet personnel, aucune exécution horaire ou quotidienne n'est planifiée afin de garder le contrôle sur les traitements et d'éviter une orchestration inutile à ce stade.

Une exécution validée a notamment produit :

```text
Début de l'ingestion Hub'Eau...
Nombre de résultats récupérés : 311
DataFrame créé : 311 lignes × 32 colonnes
Chargement vers BigQuery...
Table BigQuery chargée :
project-3665c0d5-5952-473b-82e.hubeau_raw.resultats_dis_raw
Nombre de lignes dans BigQuery : 311
Pipeline d'ingestion terminé.
```

---

# Tests Python

Les tests automatisés utilisent **pytest**.

Ils couvrent actuellement :

- la construction du DataFrame RAW ;
- l'extraction Hub'Eau avec API simulée ;
- la pagination ;
- le chargement BigQuery avec client simulé ;
- la destination BigQuery ;
- `WRITE_TRUNCATE` ;
- l'attente de la fin du job de chargement.

Exécution :

```bash
python -m pytest tests/ -v
```

État actuel :

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

Il est ensuite traité dans dbt afin d'éviter de modifier artificiellement le grain des résultats d'analyse.

---

# Organisation des datasets BigQuery

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

| Couche | Dataset BigQuery | Rôle |
|---|---|---|
| RAW | `hubeau_raw` | Données proches de la source |
| STG | `hubeau_stg` | Nettoyage léger et conservation du grain source |
| ODS / Intermediate | `hubeau_ods` | Structuration métier et préparation analytique |
| DIM | `hubeau_dim` | Dimensions décisionnelles |
| FACT | `hubeau_fact` | Mesures et faits analytiques |

---

# Modélisation dbt

Le projet dbt est intégré directement au repository :

```text
hubeau-data-pipeline/dbt/
```

## Couche STAGING

### `stg_resultats_dis`

Le modèle staging conserve les **32 champs** de la RAW et reste volontairement proche de la source.

Principes :

- conservation du grain observé ;
- absence de transformation métier lourde ;
- conservation des identifiants sous forme de chaînes ;
- conservation des valeurs `NULL` ;
- conservation simultanée de `resultat_alphanumerique` et `resultat_numerique` ;
- conservation de `reseaux` sous forme d'ARRAY.

Le modèle est matérialisé en **VIEW**.

---

# Couche ODS / Intermediate

Trois modèles intermédiaires ont été construits.

## `int_prelevements`

**Grain :**

```text
1 ligne = 1 prélèvement identifié par code_prelevement
```

Le modèle centralise notamment :

- date et heure du prélèvement ;
- attributs calendaires ;
- commune et département ;
- installation amont ;
- UGE ;
- distributeur ;
- maîtrise d'ouvrage ;
- informations globales de conformité du prélèvement.

Les informations propres aux résultats des paramètres restent séparées.

---

## `int_resultats`

**Grain :**

```text
1 ligne = 1 résultat d'analyse d'un paramètre donné pour un prélèvement
```

Le modèle contient notamment :

- identifiants du prélèvement et de l'analyse ;
- informations du paramètre ;
- résultat alphanumérique ;
- résultat numérique ;
- unité ;
- limite de qualité.

Une attention particulière est portée aux résultats censurés.

Exemple source :

```text
resultat_alphanumerique = "<0,5"
resultat_numerique      = 0.0
```

La valeur numérique seule ne permet pas de conserver la sémantique du seuil.

Le modèle dérive donc :

```text
operateur_resultat = <
seuil_resultat     = 0.5
```

De la même manière :

```text
limite_qualite_parametre = "<=50 mg/L"
```

est structurée en :

```text
operateur_limite_qualite = <=
numerique_limite_qualite = 50.0
unite_limite_qualite     = mg/L
```

Les conversions utilisent `SAFE_CAST` afin qu'un format inattendu dans la source ne fasse pas échouer l'ensemble du modèle.

---

## `int_analyses_reseaux`

Le champ `reseaux` est un tableau imbriqué dans la source.

Un `UNNEST()` direct dans le modèle principal ferait passer les données de :

```text
311 analyses
```

à :

```text
1837 éléments de réseaux
```

ce qui modifierait le grain des résultats et pourrait biaiser les agrégations.

Le traitement est donc isolé dans un modèle spécifique.

**Grain :**

```text
1 ligne = 1 association reference_analyse × code_reseau
```

Après déduplication :

```text
781 associations analyse × réseau
311 analyses
5 réseaux distincts
```

Les variantes de noms d'un même réseau sont conservées dans un `ARRAY`.

Le débit reste un attribut de la relation analyse × réseau, car il peut varier entre différentes analyses.

Un test dbt personnalisé vérifie que chaque combinaison :

```text
reference_analyse × code_reseau
```

n'apparaît qu'une seule fois.

---

# Dimensions décisionnelles

Cinq dimensions sont actuellement construites.

## `dim_date`

**Grain :**

```text
1 ligne = 1 date calendaire comprise entre
le premier et le dernier prélèvement disponibles
```

La dimension génère un calendrier continu avec `GENERATE_DATE_ARRAY`.

Elle contient notamment :

- date ;
- année ;
- trimestre ;
- mois ;
- nom du mois ;
- année-mois ;
- jour ;
- jour de la semaine ;
- nom du jour.

Validation actuelle :

```text
3811 dates
2016-01-13 → 2026-06-19
```

---

## `dim_geographie`

**Grain :**

```text
1 ligne = 1 commune identifiée par code_commune
```

Attributs :

```text
code_commune
nom_commune
code_departement
nom_departement
```

La dimension permet une future analyse aussi bien au niveau communal qu'au niveau départemental.

---

## `dim_parametre`

**Grain :**

```text
1 ligne = 1 paramètre identifié par code_parametre
```

Elle regroupe notamment :

- codes métier du paramètre ;
- code CAS lorsqu'il est disponible ;
- type de paramètre ;
- libellés ;
- unité.

Dans le périmètre actuel :

```text
code_parametre     = 1340
code_parametre_se  = NO3
code_parametre_cas = 14797-55-8
libelle_parametre  = Nitrates (en NO3)
unite              = mg/L
```

---

## `dim_installation`

**Grain :**

```text
1 ligne = 1 installation amont identifiée
par code_installation_amont
```

L'exploration a montré qu'un même code d'installation peut conserver son identité alors que son libellé évolue dans le temps.

Exemple :

```text
045000762
2016-2020 → USINE DU VAL ORLEANS
2021-2026 → USINE DE TRAITEMENT DU VAL ORLEANS
```

La dimension conserve donc comme libellé courant le nom associé au prélèvement le plus récent.

---

## `dim_reseau`

**Grain :**

```text
1 ligne = 1 réseau identifié par code_reseau
```

Contrairement aux installations, plusieurs variantes de noms d'un même réseau peuvent coexister sur une même période.

Elles sont donc conservées dans un tableau plutôt qu'un libellé choisi arbitrairement.

Validation actuelle :

```text
5 réseaux distincts
```

Exemple :

```text
045000474
├── ORLEANS
├── ORLEANS-ST JEAN LE BLANC-ST PRYVÉ
└── ORLEANS-ST JEAN LE BLANC-ST PRYVÉ-ST DENIS EN VAL
```

Le champ `debit_reseau` n'est volontairement pas intégré à cette dimension car il varie selon les analyses.

---

# Tests et qualité des données avec dbt

Les modèles dbt utilisent des tests adaptés à leurs contrats métier.

Exemples :

```text
not_null
unique
```

sur les clés des dimensions et les identifiants structurants.

Un test SQL personnalisé protège également le grain de :

```text
int_analyses_reseaux
```

en vérifiant l'unicité de :

```text
reference_analyse × code_reseau
```

La logique retenue est de tester les **contrats métier importants**, plutôt que d'ajouter mécaniquement des tests sur toutes les colonnes.

---

# Documentation de la modélisation

L'exploration et les décisions de modélisation sont documentées séparément.

```text
dbt/docs/
├── exploration_modelisation_dbt.md
└── matrice_colonnes_modelisation_dbt.md
```

### `exploration_modelisation_dbt.md`

Documente les analyses réalisées sur les données :

- grain ;
- cardinalités ;
- valeurs manquantes ;
- structure de `reseaux` ;
- valeurs censurées ;
- conformité ;
- unités ;
- installations ;
- acteurs.

### `matrice_colonnes_modelisation_dbt.md`

Documente les décisions de modélisation prises pour les **32 champs** de la source :

- conservation ;
- transformation ;
- couche cible ;
- rôle analytique ;
- justification.

Cette séparation permet de distinguer :

```text
ce qui a été observé
        ↓
ce qui a été décidé
        ↓
ce qui a été implémenté dans dbt
```

---

# Configuration dbt

Le projet dbt est situé dans :

```text
hubeau-data-pipeline/dbt/
```

Le fichier `dbt_project.yml` configure :

```text
models/staging/       → hubeau_stg
models/intermediate/  → hubeau_ods
models/dimensions/    → hubeau_dim
models/facts/         → hubeau_fact
```

Matérialisations :

```text
STG           → VIEW
ODS           → TABLE
DIM           → TABLE
FACT          → TABLE
```

La RAW BigQuery est déclarée dans :

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

Les modèles sont ensuite construits et testés avec des commandes comme :

```bash
dbt build --select nom_du_modele
```

---

# Authentification et permissions

## Ingestion Python

L'ingestion utilise le compte de service :

```text
hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

avec impersonation et **Application Default Credentials**.

Aucune clé JSON permanente de ce compte n'est stockée dans GitHub.

## dbt Cloud

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

dbt peut donc lire la RAW sans la modifier et écrire uniquement dans les datasets de transformation.

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

## 4. Configurer l'impersonation

```bash
gcloud config set auth/impersonate_service_account \
hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

## 5. Configurer les Application Default Credentials

```bash
gcloud auth application-default login \
  --impersonate-service-account=hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

## 6. Lancer le pipeline

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
│   │   └── test_int_analyses_reseaux_grain.sql
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
│       │   ├── int_analyses_reseaux.sql
│       │   └── int_analyses_reseaux.yml
│       │
│       ├── dimensions/
│       │   ├── dim_date.sql
│       │   ├── dim_date.yml
│       │   ├── dim_geographie.sql
│       │   ├── dim_geographie.yml
│       │   ├── dim_parametre.sql
│       │   ├── dim_parametre.yml
│       │   ├── dim_installation.sql
│       │   ├── dim_installation.yml
│       │   ├── dim_reseau.sql
│       │   └── dim_reseau.yml
│       │
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

# Roadmap

## Phase 1 — API et Python

- [x] Explorer l'API Hub'Eau
- [x] Identifier le périmètre initial
- [x] Implémenter l'extraction HTTP
- [x] Gérer la pagination
- [x] Construire le DataFrame RAW
- [x] Structurer le code Python
- [x] Ajouter les tests unitaires

## Phase 2 — BigQuery RAW

- [x] Définir le schéma BigQuery
- [x] Conserver `reseaux` dans sa structure imbriquée
- [x] Implémenter le chargement BigQuery
- [x] Configurer l'authentification GCP
- [x] Charger et valider la table RAW
- [x] Tester le loader BigQuery

## Phase 3 — Infrastructure dbt

- [x] Intégrer dbt au repository
- [x] Configurer les datasets RAW / STG / ODS / DIM / FACT
- [x] Connecter dbt Cloud à GitHub et BigQuery
- [x] Configurer les permissions
- [x] Déclarer la source RAW
- [x] Valider avec `dbt debug`
- [x] Valider avec `dbt parse`

## Phase 4 — Exploration et modélisation dbt

- [x] Analyser le grain et les 32 colonnes RAW
- [x] Étudier les cardinalités et valeurs manquantes
- [x] Étudier le champ imbriqué `reseaux`
- [x] Étudier les résultats censurés
- [x] Documenter les décisions de modélisation
- [x] Construire la couche STG
- [x] Construire la couche ODS
- [x] Construire `int_prelevements`
- [x] Construire `int_resultats`
- [x] Construire `int_analyses_reseaux`
- [x] Ajouter les tests dbt
- [x] Construire `dim_date`
- [x] Construire `dim_geographie`
- [x] Construire `dim_parametre`
- [x] Construire `dim_installation`
- [x] Construire `dim_reseau`
- [x] Documenter les modèles DIM
- [ ] Concevoir la ou les tables FACT
- [ ] Construire les modèles FACT
- [ ] Ajouter les tests des modèles FACT
- [ ] Valider le modèle décisionnel final

## Phase 5 — Analytics / BI

- [ ] Définir les KPI
- [ ] Définir les mesures analytiques
- [ ] Connecter Power BI
- [ ] Construire les visualisations
- [ ] Construire le tableau de bord
- [ ] Documenter les indicateurs

---

# Principes de modélisation

Le projet suit notamment les principes suivants :

- séparation entre exploration, ingestion, stockage et transformation ;
- couche RAW proche de la donnée source ;
- schéma BigQuery explicite ;
- conservation des structures imbriquées lorsqu'elles ont une valeur métier ;
- transformations métier réalisées dans dbt ;
- séparation physique RAW / STG / ODS / DIM / FACT ;
- définition explicite du grain de chaque modèle ;
- vérification des données avant de définir une règle de modélisation ;
- séparation entre attributs d'entité et attributs de relation ;
- conservation de la sémantique des valeurs censurées ;
- absence de choix arbitraire lorsqu'un identifiant possède plusieurs libellés ;
- tests ciblés sur les contrats métier importants ;
- principe du moindre privilège pour les accès BigQuery ;
- composants Python testables indépendamment ;
- absence de secrets permanents dans Git ;
- déclenchement manuel maîtrisé ;
- documentation progressive des décisions techniques et métier ;
- versionnement Git / GitHub.

---

# Prochaine étape

La prochaine phase du projet est la construction de la couche **FACT**.

Elle devra notamment permettre de relier les résultats d'analyse aux dimensions :

```text
                    dim_date
                       │
                       │
dim_geographie ───┐    │
                  │    │
dim_parametre ────┼── FACT résultats
                  │
dim_installation ─┤
                  │
dim_reseau ───────┘
```

La conception de cette couche sera pilotée par les futurs besoins analytiques et KPI, afin de déterminer précisément :

- le grain de la table de faits ;
- les clés de dimensions ;
- les mesures ;
- le traitement des résultats censurés ;
- le traitement des seuils de qualité ;
- les relations avec les réseaux ;
- les indicateurs destinés à Power BI.
