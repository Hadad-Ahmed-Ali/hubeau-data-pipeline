# Documentation technique - Pipeline Hub'Eau

## Introduction

Ce document décrit l'architecture technique, les composants et les principaux choix d'implémentation du projet **Hub'Eau Data Pipeline**.

Le projet construit un pipeline **Data Analytics Engineering** de bout en bout à partir des données publiques de qualité de l'eau potable fournies par l'API **Hub'Eau**.

Le périmètre actuellement modélisé porte sur la commune d'**Orléans** et couvre **12 paramètres physico-chimiques et microbiologiques**, soit **19 923 résultats d'analyse** sur une période allant de **2016 à 2026**.

L'architecture est organisée en trois grandes parties :

```text
I. INGESTION

API Hub'Eau
     │
     ▼
Python
     │
     ▼
BigQuery RAW


II. TRANSFORMATION & MODÉLISATION

BigQuery RAW
     │
     ▼
dbt
     │
     ├── STG
     ├── ODS / Intermediate
     ├── DIM
     ├── FACT
     └── BRIDGE
     │
     ▼
BigQuery
Modèle analytique


III. ANALYTICS

DIM / FACT / BRIDGE
     │
     ▼
Power BI
KPI · analyses · tableaux de bord
```

Cette séparation permet de distinguer clairement :

- l'acquisition et le stockage des données sources ;
- la transformation et la fiabilisation des objets métier ;
- la construction du modèle analytique ;
- l'exploitation des données dans la couche de restitution.

> Le détail des grains, clés, cardinalités et décisions de modélisation est présenté dans le document  
> **[Schéma analytique et décisions de modélisation](schema_analytics/schema_analytics.md)**.

---

# I - Ingestion : API Hub'Eau → Python → BigQuery RAW

## 1. Présentation de la source

Le projet utilise l'API publique **Hub'Eau — Qualité de l'eau potable**.

L'endpoint utilisé est :

```text
qualite_eau_potable/resultats_dis
```

Il fournit les résultats d'analyses réalisées sur les prélèvements d'eau distribuée.

Le rôle de la couche d'ingestion est de :

1. interroger l'API Hub'Eau ;
2. gérer la pagination ;
3. gérer certaines erreurs HTTP temporaires ;
4. récupérer les observations du périmètre sélectionné ;
5. convertir les données JSON en DataFrame pandas ;
6. effectuer uniquement les préparations techniques nécessaires au stockage ;
7. charger les données dans BigQuery RAW.

Le principe retenu est :

```text
API
 │
 ▼
Préparation technique minimale
 │
 ▼
RAW proche de la source
 │
 ▼
Transformations métier dans dbt
```

Les transformations analytiques ne sont donc pas réalisées dans la couche Python.

---

## 2. Périmètre actuel

Le périmètre géographique est actuellement limité à :

```text
code_commune = 45234
commune      = Orléans
```

L'ingestion couvre **12 paramètres de qualité de l'eau** :

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

Lors de l'ingestion utilisée pour la modélisation :

```text
19 923 résultats
32 champs
12 paramètres
2016 → 2026
```

La répartition des résultats est :

| Code | Paramètre | Nombre de résultats |
|---:|---|---:|
| `1295` | Turbidité | 1 910 |
| `1301` | Température | 1 914 |
| `1302` | pH | 2 205 |
| `1303` | Conductivité | 1 908 |
| `1335` | Ammonium | 1 908 |
| `1339` | Nitrites | 366 |
| `1340` | Nitrates | 311 |
| `1393` | Fer | 1 839 |
| `1394` | Manganèse | 1 833 |
| `1398` | Chlore libre | 1 913 |
| `1449` | Escherichia coli | 1 908 |
| `6455` | Entérocoques | 1 908 |
|  | **Total** | **19 923** |

Ces volumes correspondent au jeu de données actuellement chargé et modélisé. Ils peuvent évoluer lorsque de nouvelles analyses sont publiées par Hub'Eau.

L'extension du périmètre initial, limité aux nitrates, vers 12 paramètres a permis de confronter le pipeline à plusieurs problématiques réelles : unités différentes, résultats censurés, valeurs non mesurées, lieux d'analyse et seuils de qualité variables.

---

## 3. Structure des données sources

La table RAW contient **32 champs** décrivant plusieurs catégories d'informations.

### 3.1 Prélèvement

Exemples :

```text
code_prelevement
date_prelevement
conclusion_conformite_prelevement
conformite_limites_bact_prelevement
conformite_limites_pc_prelevement
conformite_references_bact_prelevement
conformite_references_pc_prelevement
```

### 3.2 Résultat et analyse

Exemples :

```text
reference_analyse
code_lieu_analyse
resultat_alphanumerique
resultat_numerique
```

### 3.3 Paramètre

Exemples :

```text
code_parametre
code_parametre_se
code_parametre_cas
libelle_parametre
libelle_parametre_maj
libelle_parametre_web
code_type_parametre
code_unite
libelle_unite
```

### 3.4 Qualité

```text
limite_qualite_parametre
reference_qualite_parametre
```

### 3.5 Géographie et installations

Exemples :

```text
code_commune
nom_commune
code_departement
nom_departement
code_installation_amont
nom_installation_amont
```

### 3.6 Réseaux

Le champ :

```text
reseaux
```

est un tableau imbriqué contenant :

```text
code
nom
debit
```

Cette structure est conservée dans la RAW et n'est pas aplatie pendant l'ingestion.

---

## 4. Module d'ingestion Python

La logique d'extraction est principalement implémentée dans :

```text
src/ingestion/hubeau_api.py
```

Elle couvre notamment :

- les appels HTTP ;
- la transmission des paramètres ;
- la pagination ;
- l'agrégation des pages ;
- la gestion de certaines erreurs temporaires HTTP.

### Gestion des erreurs HTTP temporaires

Une fonction dédiée :

```text
get_with_retry()
```

gère notamment les réponses HTTP `503`.

En cas d'indisponibilité temporaire, plusieurs tentatives sont réalisées avec des temps d'attente successifs avant de propager l'erreur si le service reste indisponible.

Cette logique rend l'ingestion plus robuste face aux indisponibilités ponctuelles de l'API.

---

## 5. Pagination

L'API Hub'Eau peut retourner plusieurs pages.

Chaque réponse contient notamment :

```text
data
next
```

Le pipeline suit automatiquement `next` jusqu'à la dernière page :

```text
Page 1
 │
 ▼
Page 2
 │
 ▼
...
 │
 ▼
Dernière page
next = None
```

Cette logique permet de récupérer l'intégralité des observations correspondant au paramètre demandé sans supposer un nombre fixe de pages.

---

## 6. Ingestion multi-paramètres

Le point d'entrée du pipeline est :

```text
src/run_ingestion.py
```

Il orchestre l'extraction des **12 paramètres sélectionnés**.

Conceptuellement :

```text
12 codes_parametre
        │
        ▼
Boucle d'extraction
        │
        ├── paramètre 1 → pagination
        ├── paramètre 2 → pagination
        ├── ...
        └── paramètre 12 → pagination
                    │
                    ▼
         Ensemble des observations
                    │
                    ▼
            DataFrame pandas
                    │
                    ▼
             Chargement RAW
```

Les observations sont réunies dans un DataFrame unique avant le chargement dans BigQuery.

---

## 7. Construction du DataFrame RAW

La fonction :

```text
build_raw_dataframe()
```

convertit les observations récupérées en DataFrame pandas.

La couche Python effectue volontairement peu de transformations.

Le champ :

```text
date_prelevement
```

est notamment converti vers un type datetime compatible avec le type BigQuery :

```text
TIMESTAMP
```

Les transformations métier plus complexes restent déléguées à dbt.

---

## 8. Conservation du champ `reseaux`

Une observation peut être associée à plusieurs réseaux.

Structure simplifiée :

```text
reseaux
 │
 ├── code
 │   nom
 │   debit
 │
 └── code
     nom
     debit
```

Le champ n'est volontairement pas aplati en Python.

Dans BigQuery, il est stocké sous la forme :

```text
ARRAY<STRUCT<
    code STRING,
    nom STRING,
    debit STRING
>>
```

Ce choix permet :

- de conserver la structure de la source ;
- d'éviter de multiplier prématurément les lignes ;
- de différer la définition du grain analytique jusqu'à l'exploration dbt.

Le champ est ensuite exploité avec `UNNEST()` dans les transformations appropriées.

---

## 9. BigQuery RAW

Les données sont chargées dans :

```text
project-3665c0d5-5952-473b-82e
└── hubeau_raw
    └── resultats_dis_raw
```

Région :

```text
europe-west1
```

Le schéma BigQuery est défini explicitement dans :

```text
src/loading/bigquery_loader.py
```

et contient **32 champs**.

Quelques types structurants :

```text
date_prelevement     TIMESTAMP
resultat_numerique   FLOAT64
reseaux              ARRAY<STRUCT<...>>
```

L'utilisation d'un schéma explicite permet :

- de maîtriser les types ;
- de rendre le chargement reproductible ;
- de documenter la structure attendue ;
- de ne pas dépendre uniquement de l'inférence automatique de BigQuery.

---

## 10. Chargement Python → BigQuery

Le chargement est implémenté dans :

```text
src/loading/bigquery_loader.py
```

La fonction principale :

```text
load_to_bigquery()
```

utilise le client Python BigQuery et :

```python
client.load_table_from_dataframe(...)
```

Le chargement est configuré avec :

```text
WRITE_TRUNCATE
```

Le fonctionnement est donc :

```text
Extraction complète
       │
       ▼
DataFrame RAW
       │
       ▼
WRITE_TRUNCATE
       │
       ▼
resultats_dis_raw
```

Cette stratégie reste adaptée au périmètre actuel :

- volume maîtrisé ;
- extraction complète simple ;
- reproductibilité ;
- absence de complexité incrémentale inutile.

Une stratégie incrémentale pourrait être étudiée si le périmètre ou le volume augmentait significativement.

---

## 11. Authentification de l'ingestion

Le client BigQuery Python est créé avec :

```python
bigquery.Client(project=project_id)
```

Il s'appuie donc sur les **Application Default Credentials (ADC)** disponibles dans l'environnement d'exécution.

Un compte de service dédié à l'ingestion existe :

```text
hubeau-pipeline@project-3665c0d5-5952-473b-82e.iam.gserviceaccount.com
```

Aucune clé JSON permanente de ce compte n'est stockée dans GitHub.

Selon l'environnement local, les ADC peuvent être configurées afin d'utiliser les autorisations appropriées.

Cette séparation permet de conserver le code indépendant d'un fichier de credentials versionné.

---

## 12. Déclenchement

Le pipeline d'ingestion est actuellement **déclenché manuellement**.

```bash
python src/run_ingestion.py
```

Ce choix est volontaire :

- les données n'ont pas besoin d'un rafraîchissement continu dans le cadre du projet ;
- il permet de maîtriser les exécutions et les coûts ;
- il évite d'introduire une orchestration inutile à ce stade ;
- l'architecture reste automatisable ultérieurement.

Le flux complet est :

```text
run_ingestion.py
       │
       ▼
12 paramètres
       │
       ▼
API Hub'Eau
       │
       ▼
Pagination
       │
       ▼
DataFrame RAW
       │
       ▼
BigQuery
       │
       ▼
hubeau_raw.resultats_dis_raw
```

---

## 13. Tests Python

Les tests utilisent **pytest** :

```text
tests/
├── test_hubeau_api.py
└── test_bigquery_loader.py
```

Ils couvrent notamment :

- la construction du DataFrame RAW ;
- la conversion de `date_prelevement` ;
- les appels API simulés ;
- la pagination ;
- le chargement BigQuery avec client simulé ;
- la destination BigQuery ;
- `WRITE_TRUNCATE` ;
- l'attente de la fin du job.

Les dépendances externes sont simulées afin que les tests n'aient pas besoin d'appeler systématiquement l'API ou BigQuery.

Exécution :

```bash
python -m pytest tests/ -v
```

État validé :

```text
4 tests passed
```

> La logique de retry HTTP existe dans le code d'ingestion, mais ne dispose pas actuellement d'un test unitaire dédié.

---

# II - Transformation et modélisation : BigQuery RAW → dbt

## 14. Rôle de dbt

La séparation des responsabilités est :

```text
Python
 │
 └── acquisition et chargement
             │
             ▼
       BigQuery RAW
             │
             ▼
            dbt
             │
             └── transformation
                 structuration métier
                 tests
                 modélisation analytique
```

dbt transforme :

```text
hubeau_raw.resultats_dis_raw
```

jusqu'aux tables destinées à la future couche de restitution.

---

## 15. Organisation des datasets BigQuery

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

| Dataset | Rôle |
|---|---|
| `hubeau_raw` | Données proches de la source |
| `hubeau_stg` | Staging et conservation du grain source |
| `hubeau_ods` | Structuration et fiabilisation des objets métier |
| `hubeau_dim` | Dimensions analytiques |
| `hubeau_fact` | Tables de faits et table de pont |

Tous les datasets sont situés dans :

```text
europe-west1
```

---

## 16. Configuration dbt

Le projet dbt est situé dans :

```text
dbt/
```

Le fichier :

```text
dbt/dbt_project.yml
```

configure :

```text
models/staging/       → hubeau_stg  → VIEW
models/intermediate/  → hubeau_ods  → TABLE
models/dimensions/    → hubeau_dim  → TABLE
models/facts/         → hubeau_fact → TABLE
models/bridges/       → hubeau_fact → TABLE
```

La table RAW est déclarée dans :

```text
dbt/models/sources.yml
```

et référencée avec :

```sql
{{ source('hubeau_raw', 'resultats_dis_raw') }}
```

Les dépendances entre modèles sont définies avec :

```sql
{{ ref('nom_du_modele') }}
```

---

## 17. Gestion des datasets dbt

Un macro personnalisé est défini dans :

```text
dbt/macros/generate_schema_name.sql
```

afin d'utiliser directement les datasets personnalisés configurés dans `dbt_project.yml`.

Ainsi :

```text
+schema: hubeau_stg
```

produit directement :

```text
hubeau_stg
```

et non une concaténation avec le dataset de développement.

---

## 18. Connexion dbt Cloud, GitHub et BigQuery

L'architecture de développement est :

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

Le sous-répertoire dbt Cloud est :

```text
dbt
```

La connexion BigQuery utilise :

```text
Location : europe-west1
```

La configuration a été validée avec :

```bash
dbt debug
dbt parse
```

Le code dbt est versionné dans le même repository que l'ingestion Python afin de conserver l'ensemble du pipeline dans un projet unique.

---

## 19. Permissions dbt

Le compte de service utilisé par dbt dispose au niveau projet des rôles nécessaires à l'exécution des traitements :

```text
BigQuery Job User
BigQuery Read Session User
```

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

dbt peut donc :

- lire la RAW ;
- créer et mettre à jour les modèles de transformation ;
- ne pas modifier directement la couche RAW.

---

# III - Exploration et décisions de modélisation

## 20. Principe de conception

La modélisation n'a pas été construite directement à partir du nom des colonnes.

Avant la création des modèles analytiques, les données ont été explorées afin de déterminer :

- les grains réels ;
- les cardinalités ;
- les valeurs manquantes ;
- la stabilité des attributs ;
- les résultats censurés ;
- les limites et références de qualité ;
- la structure et le comportement de `reseaux` ;
- les variantes historiques de libellés.

La logique suivie est :

```text
Observation
    │
    ▼
Hypothèse
    │
    ▼
Vérification SQL
    │
    ▼
Décision de modélisation
    │
    ▼
Implémentation dbt
    │
    ▼
Test
```

Deux documents conservent le détail de ce travail :

```text
dbt/docs/
├── exploration_modelisation_dbt.md
└── matrice_colonnes_modelisation_dbt.md
```

Le premier documente **ce qui a été observé**.

Le second formalise **ce qui a été décidé pour les 32 champs de la source**.

---

## 21. Grain des résultats

L'exploration a montré qu'un prélèvement peut contenir plusieurs résultats de paramètres.

La combinaison :

```text
code_prelevement
+ code_parametre
```

n'est pas toujours suffisante pour identifier un résultat.

Le pH peut notamment être présent pour plusieurs lieux d'analyse.

Sur le périmètre étudié, la combinaison :

```text
code_prelevement
+ code_parametre
+ code_lieu_analyse
```

ne présente aucun doublon.

Le grain retenu pour les résultats est donc :

> **1 ligne = 1 résultat d'un paramètre donné, pour un prélèvement donné et un lieu d'analyse donné.**

Cette règle est fondée sur le périmètre actuellement étudié et ne constitue pas une hypothèse universelle sur l'ensemble de l'API Hub'Eau.

---

## 22. Rôle de `reference_analyse`

L'exploration a montré que :

```text
reference_analyse
```

- peut être `NULL` ;
- n'est pas unique au grain des résultats ;
- peut être partagée par plusieurs paramètres.

Elle est donc conservée comme information issue de la source, mais n'est pas utilisée comme clé du résultat.

---

## 23. Résultats censurés et non mesurés

`resultat_numerique` ne suffit pas à représenter tous les résultats.

Exemple :

```text
resultat_alphanumerique = "<0,10"
resultat_numerique      = 0.0
```

Interpréter uniquement `resultat_numerique` conduirait à traiter cette observation comme un zéro exact.

Le modèle conserve donc :

```text
resultat_alphanumerique
resultat_numerique
operateur_resultat
seuil_resultat
```

Les valeurs telles que :

```text
N.M.
```

sont également conservées sans leur attribuer artificiellement une valeur numérique.

---

## 24. Limites et références de qualité

Les expressions sources :

```text
limite_qualite_parametre
reference_qualite_parametre
```

sont conservées.

Elles sont également structurées en champs analytiques permettant de représenter :

```text
opérateur minimum
valeur minimum
opérateur maximum
valeur maximum
unité
```

L'exploration a montré qu'un même paramètre peut être associé à plusieurs seuils selon les observations.

Ces informations ne sont donc pas considérées comme de simples attributs fixes de `dim_parametre`.

Elles restent au grain du résultat.

Les **limites de qualité** et les **références de qualité** restent également séparées afin de préserver les deux notions de la source.

---

## 25. Modélisation des réseaux

L'exploration des **19 923 résultats** a montré que, sur le périmètre étudié, les différents résultats appartenant à un même prélèvement présentent la même configuration de codes réseau.

La relation réseau peut donc être structurée au grain :

> **1 ligne = 1 association entre un prélèvement et un réseau.**

Le modèle intermédiaire :

```text
int_prelevements_reseaux
```

contient :

```text
code_prelevement
code_reseau
```

Validation du périmètre actuel :

```text
5 197 associations prélèvement × réseau
1 914 prélèvements
6 réseaux
```

Le champ `debit` n'est pas utilisé comme facteur de pondération.

Son exploration n'a pas permis de démontrer qu'il pouvait être interprété de manière fiable comme un poids de répartition des concentrations entre réseaux.

Aucune pondération analytique n'est donc introduite sans justification métier.

---

# IV - Couches dbt

## 26. STAGING — `stg_resultats_dis`

Le modèle :

```text
stg_resultats_dis
```

préserve le grain et les **32 champs** de la RAW.

**Grain :**

> **1 ligne = 1 résultat brut retourné par l'API Hub'Eau.**

La couche STG :

- reste proche de la source ;
- conserve `reseaux` sous forme imbriquée ;
- ne réalise pas de transformation métier lourde ;
- prépare la séparation des objets métier dans l'ODS.

Matérialisation :

```text
VIEW
```

Volume actuellement modélisé :

```text
19 923 lignes
```

---

## 27. ODS — `int_prelevements`

**Grain :**

> **1 ligne = 1 prélèvement identifié par `code_prelevement`.**

Le modèle regroupe les informations propres au prélèvement :

- date et heure ;
- commune ;
- installation amont ;
- acteurs associés ;
- indicateurs de conformité du prélèvement.

Validation :

```text
1 914 lignes
1 914 code_prelevement distincts
```

---

## 28. ODS — `int_resultats`

**Grain :**

> **1 ligne = 1 résultat d'un paramètre donné, pour un prélèvement donné et un lieu d'analyse donné.**

Le modèle structure notamment :

- l'identification du résultat ;
- le paramètre ;
- le lieu d'analyse ;
- la représentation alphanumérique ;
- la représentation numérique ;
- l'opérateur et le seuil ;
- les limites de qualité ;
- les références de qualité.

Volume :

```text
19 923 lignes
```

Un test SQL personnalisé contrôle le grain composite.

---

## 29. ODS — `int_prelevements_reseaux`

**Grain :**

> **1 ligne = 1 association entre un prélèvement et un réseau.**

Le modèle est obtenu à partir de l'éclatement du tableau `reseaux` puis de la déduplication des associations.

Il ne conserve volontairement ni le nom du réseau ni le débit :

- les variantes de noms sont gérées dans `dim_reseau` ;
- le débit n'est pas interprété comme un poids analytique.

Volume :

```text
5 197 lignes
```

---

# V - Modèle analytique

## 30. Vue générale

La couche analytique est désormais construite.

Elle comprend :

```text
5 dimensions
2 tables de faits
1 table de pont
```

```text
DIM
├── dim_date
├── dim_geographie
├── dim_installation
├── dim_parametre
└── dim_reseau

FACT
├── fact_prelevements
└── fact_resultats

BRIDGE
└── bridge_prelevements_reseaux
```

La documentation détaillée du modèle est disponible ici :

➡️ **[Schéma analytique et décisions de modélisation](schema_analytics/schema_analytics.md)**

Elle présente notamment :

- les dépendances dbt ;
- les grains ;
- les clés métier ;
- les relations PK/FK analytiques ;
- les cardinalités ;
- la relation N:N prélèvement ↔ réseau ;
- les principales décisions de modélisation.

---

## 31. Dimensions

### `dim_date`

**Grain :**

> 1 ligne = 1 date calendaire.

Elle génère un calendrier continu couvrant la période des prélèvements.

---

### `dim_geographie`

**Grain :**

> 1 ligne = 1 commune identifiée par `code_commune`.

Elle porte notamment les informations de commune et département.

---

### `dim_installation`

**Grain :**

> 1 ligne = 1 installation identifiée par `code_installation_amont`.

L'exploration a montré que le nom associé à une installation peut évoluer dans le temps.

La dimension conserve le libellé observé le plus récemment pour chaque code.

Cette simplification correspond à une dimension portant le libellé courant et non à une gestion historique de type SCD2.

---

### `dim_parametre`

**Grain :**

> 1 ligne = 1 paramètre identifié par `code_parametre`.

Elle décrit les **12 paramètres** du périmètre :

- codes ;
- libellés ;
- type ;
- code CAS lorsqu'il est disponible ;
- unité.

Les limites et références de qualité ne sont pas intégrées comme attributs fixes de cette dimension.

---

### `dim_reseau`

**Grain :**

> 1 ligne = 1 réseau identifié par `code_reseau`.

Plusieurs variantes de noms peuvent être observées pour un même réseau.

La dimension conserve donc les différents libellés observés dans un tableau plutôt que de sélectionner arbitrairement un nom unique.

Validation :

```text
6 réseaux
```

---

## 32. `fact_prelevements`

**Grain :**

> **1 ligne = 1 prélèvement identifié par `code_prelevement`.**

Volume :

```text
1 914 lignes
```

La table permet les analyses des prélèvements selon :

- la date ;
- la géographie ;
- l'installation.

Elle porte également les indicateurs de conformité concernant le prélèvement dans son ensemble.

Ce choix évite de répéter ces informations pour chaque résultat d'analyse.

---

## 33. `fact_resultats`

**Grain :**

> **1 ligne = 1 résultat d'un paramètre donné, pour un prélèvement donné et un lieu d'analyse donné.**

Volume :

```text
19 923 lignes
```

Elle permet les analyses selon :

- le paramètre ;
- la date ;
- la commune ;
- l'installation ;
- le lieu d'analyse.

Elle conserve également :

- la représentation source du résultat ;
- sa représentation numérique lorsqu'elle existe ;
- l'opérateur et le seuil ;
- les limites de qualité ;
- les références de qualité.

La combinaison :

```text
code_prelevement
+ code_parametre
+ code_lieu_analyse
```

est contrôlée par un test dbt dédié.

---

## 34. `bridge_prelevements_reseaux`

La relation métier entre les prélèvements et les réseaux est une relation :

```text
N:N
```

Un prélèvement peut être associé à plusieurs réseaux et un réseau à plusieurs prélèvements.

Placer directement `code_reseau` dans `fact_prelevements` provoquerait une duplication des prélèvements et casserait le grain de la table de faits.

La relation est donc matérialisée avec :

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

**Grain de la bridge :**

> **1 ligne = 1 association unique entre un prélèvement et un réseau.**

Volume :

```text
5 197 lignes
```

Cette structure préserve le grain des faits tout en permettant l'analyse des prélèvements par réseau.

---

## 35. Relations analytiques

Les principales relations sont :

```text
dim_date
    │
    ├──► fact_prelevements
    └──► fact_resultats

dim_geographie
    │
    ├──► fact_prelevements
    └──► fact_resultats

dim_installation
    │
    ├──► fact_prelevements
    └──► fact_resultats

dim_parametre
    │
    └──► fact_resultats

dim_reseau
    │
    ▼
bridge_prelevements_reseaux
    ▲
    │
fact_prelevements
```

Les clés indiquées dans le modèle sont des **clés métier dont l'unicité est contrôlée par la logique dbt et les tests**. Elles ne correspondent pas nécessairement à des contraintes physiques `PRIMARY KEY` déclarées dans BigQuery.

Pour les cardinalités détaillées :

➡️ **[Consulter le schéma analytique](schema_analytics/schema_analytics.md)**

---

# VI - Tests et qualité des données

## 36. Stratégie de tests dbt

Les tests sont définis à partir des contrats métier des modèles.

Les tests génériques comprennent notamment :

```text
not_null
unique
relationships
```

Ils contrôlent :

- les identifiants structurants ;
- les clés métier ;
- les relations entre dimensions, faits et bridge.

La stratégie n'est pas d'ajouter mécaniquement un test à chaque colonne, mais de protéger les propriétés importantes du modèle.

---

## 37. Tests de grain personnalisés

Certains grains reposent sur plusieurs colonnes.

Des tests SQL dédiés sont donc utilisés :

```text
dbt/tests/
├── test_int_resultats_grain.sql
├── test_int_prelevements_reseaux_grain.sql
├── test_fact_resultats_grain.sql
└── test_bridge_prelevements_reseaux_grain.sql
```

Ils vérifient notamment l'absence de doublons pour :

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

Ces tests permettent de transformer les hypothèses de grain issues de l'exploration en **contrats vérifiables du pipeline**.

---

## 38. Tests de relations

Les fichiers YAML des modèles analytiques contrôlent également les relations structurantes, notamment :

```text
fact_prelevements.date_prelevement
    → dim_date.date

fact_prelevements.code_commune
    → dim_geographie.code_commune

fact_prelevements.code_installation_amont
    → dim_installation.code_installation_amont

fact_resultats.code_parametre
    → dim_parametre.code_parametre

fact_resultats.date_prelevement
    → dim_date.date

fact_resultats.code_commune
    → dim_geographie.code_commune

fact_resultats.code_installation_amont
    → dim_installation.code_installation_amont

bridge_prelevements_reseaux.code_prelevement
    → fact_prelevements.code_prelevement

bridge_prelevements_reseaux.code_reseau
    → dim_reseau.code_reseau
```

---

# VII - Documentation de la modélisation

## 39. Organisation documentaire

La documentation technique est volontairement séparée selon son rôle :

```text
README.md
│
│ Présentation générale / vitrine du projet
│
├── docs/pipeline_hubeau.md
│   Architecture et fonctionnement technique du pipeline
│
├── docs/schema_analytics/schema_analytics.md
│   Modèle analytique, grains, clés et cardinalités
│
├── dbt/docs/exploration_modelisation_dbt.md
│   Observations et analyses réalisées sur les données
│
└── dbt/docs/matrice_colonnes_modelisation_dbt.md
    Décisions de modélisation champ par champ
```

La logique documentaire est :

```text
Observation
     │
     ▼
Décision
     │
     ▼
Implémentation
     │
     ▼
Architecture analytique
```

Cette séparation évite de mélanger les constats issus des données avec les choix de conception qui en découlent.

---

# VIII - Structure du repository

## 40. Organisation actuelle

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
│   ├── macros/
│   │   └── generate_schema_name.sql
│   ├── docs/
│   │   ├── exploration_modelisation_dbt.md
│   │   └── matrice_colonnes_modelisation_dbt.md
│   ├── tests/
│   │   ├── test_int_resultats_grain.sql
│   │   ├── test_int_prelevements_reseaux_grain.sql
│   │   ├── test_fact_resultats_grain.sql
│   │   └── test_bridge_prelevements_reseaux_grain.sql
│   └── models/
│       ├── sources.yml
│       ├── staging/
│       │   ├── stg_resultats_dis.sql
│       │   └── stg_resultats_dis.yml
│       ├── intermediate/
│       │   ├── int_prelevements.sql
│       │   ├── int_prelevements.yml
│       │   ├── int_resultats.sql
│       │   ├── int_resultats.yml
│       │   ├── int_prelevements_reseaux.sql
│       │   └── int_prelevements_reseaux.yml
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
│       ├── facts/
│       │   ├── fact_prelevements.sql
│       │   ├── fact_prelevements.yml
│       │   ├── fact_resultats.sql
│       │   └── fact_resultats.yml
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

# IX - Roadmap technique

## Phase 1 - Exploration et ingestion Python

- [x] Étudier l'API Hub'Eau
- [x] Tester l'endpoint `resultats_dis`
- [x] Comprendre la structure JSON
- [x] Identifier la structure imbriquée `reseaux`
- [x] Implémenter la pagination
- [x] Construire le DataFrame RAW
- [x] Convertir `date_prelevement`
- [x] Structurer le code Python
- [x] Ajouter les tests unitaires
- [x] Étendre l'ingestion à 12 paramètres

---

## Phase 2 - BigQuery RAW

- [x] Créer le dataset `hubeau_raw`
- [x] Définir un schéma BigQuery explicite
- [x] Conserver `reseaux` sous forme imbriquée
- [x] Implémenter le loader Python BigQuery
- [x] Utiliser `WRITE_TRUNCATE`
- [x] Configurer l'authentification
- [x] Charger `resultats_dis_raw`
- [x] Valider le schéma
- [x] Charger les 19 923 résultats multi-paramètres
- [x] Intégrer le chargement dans `run_ingestion.py`
- [x] Tester le loader BigQuery

---

## Phase 3 - Infrastructure dbt

- [x] Intégrer dbt au repository
- [x] Configurer les datasets STG / ODS / DIM / FACT
- [x] Configurer `dbt_project.yml`
- [x] Configurer `generate_schema_name.sql`
- [x] Connecter dbt Cloud à GitHub
- [x] Connecter dbt Cloud à BigQuery
- [x] Configurer les permissions IAM
- [x] Déclarer la source RAW
- [x] Valider la connexion avec `dbt debug`
- [x] Valider le projet avec `dbt parse`

---

## Phase 4 - Exploration et modélisation dbt

- [x] Analyser les 32 champs RAW
- [x] Étudier les grains et cardinalités
- [x] Étudier les valeurs manquantes
- [x] Étudier les résultats censurés et non mesurés
- [x] Étudier les limites et références de qualité
- [x] Étudier la structure `reseaux`
- [x] Documenter l'exploration
- [x] Documenter les décisions champ par champ
- [x] Construire et tester STG
- [x] Construire et tester `int_prelevements`
- [x] Construire et tester `int_resultats`
- [x] Construire et tester `int_prelevements_reseaux`
- [x] Construire les 5 dimensions
- [x] Construire `fact_prelevements`
- [x] Construire `fact_resultats`
- [x] Construire `bridge_prelevements_reseaux`
- [x] Ajouter les tests de relations
- [x] Ajouter les tests de grains composites
- [x] Valider le modèle analytique
- [x] Documenter les grains, clés et cardinalités

---

## Phase 5 - Analytics / Power BI

- [ ] Définir les KPI
- [ ] Définir les mesures analytiques
- [ ] Connecter Power BI à BigQuery
- [ ] Construire le modèle de restitution
- [ ] Construire les visualisations
- [ ] Construire le tableau de bord
- [ ] Documenter les indicateurs

---

# X - Principes techniques du projet

Le projet repose sur plusieurs principes.

1. **Séparer exploration et code réutilisable**  
   Les notebooks servent à comprendre les données ; la logique du pipeline est placée dans `src/`.

2. **Conserver une RAW proche de la source**  
   Python réalise uniquement les préparations techniques nécessaires au stockage.

3. **Préserver les structures utiles**  
   `reseaux` reste imbriqué dans la RAW et n'est éclaté qu'au moment où son grain métier est compris.

4. **Séparer ingestion et transformation**  
   Python acquiert et charge les données ; dbt structure et modélise les données.

5. **Séparer physiquement les couches**  
   RAW, STG, ODS, DIM et FACT disposent de datasets BigQuery dédiés.

6. **Définir explicitement les grains**  
   Chaque modèle dbt possède un grain métier documenté et, lorsque nécessaire, testé.

7. **Observer avant de modéliser**  
   Les clés et relations sont définies à partir de l'exploration des données plutôt qu'à partir du seul nom des colonnes.

8. **Préserver la sémantique des résultats**  
   Les valeurs censurées et non mesurées ne sont pas artificiellement transformées en mesures numériques exactes.

9. **Ne pas figer des règles variables dans les dimensions**  
   Les limites et références de qualité restent au grain du résultat lorsqu'elles peuvent varier.

10. **Préserver le grain face aux relations N:N**  
    La relation prélèvement ↔ réseau est isolée dans une table de pont.

11. **Éviter les hypothèses métier non démontrées**  
    Le débit réseau n'est pas utilisé comme facteur de pondération sans justification suffisante.

12. **Tester les contrats métier**  
    Les tests dbt portent sur les clés, relations et grains importants plutôt que sur une accumulation mécanique de contrôles.

13. **Appliquer le moindre privilège**  
    dbt lit la RAW et écrit uniquement dans les datasets de transformation.

14. **Éviter les secrets permanents dans Git**  
    Aucun fichier de credentials nécessaire à l'ingestion n'est versionné.

15. **Maîtriser le déclenchement du pipeline**  
    L'ingestion reste volontairement manuelle dans le contexte actuel.

16. **Versionner l'ensemble du projet**  
    Python, dbt, tests et documentation sont regroupés dans le même repository GitHub.

17. **Documenter les décisions**  
    L'exploration, les choix champ par champ et l'architecture analytique disposent de documents distincts.

---

# XI - État actuel et prochaine phase

## Pipeline Data - construit et validé

```text
Hub'Eau API
     │
     ▼
Python
12 paramètres
pagination
gestion erreurs
     │
     ▼
BigQuery RAW
19 923 résultats
32 champs
     │
     ▼
dbt
     │
     ├── STG
     │
     ├── ODS
     │
     ├── 5 DIM
     │
     ├── 2 FACT
     │
     └── 1 BRIDGE
     │
     ▼
BigQuery
Modèle analytique
testé et documenté
```

La partie **ingestion → stockage → transformation → modélisation analytique** est désormais construite sur le périmètre actuel.

## Prochaine phase : Analytics & Power BI

```text
Modèle analytique BigQuery
          │
          ▼
Définition des KPI
          │
          ▼
Mesures analytiques
          │
          ▼
Power BI
          │
          ▼
Visualisations
          │
          ▼
Dashboard
```

Le prochain travail consistera notamment à définir :

- les KPI pertinents pour les 12 paramètres ;
- les règles d'exploitation des limites et références de qualité ;
- les analyses temporelles ;
- les analyses par paramètre ;
- les analyses par installation et réseau ;
- les indicateurs de conformité des prélèvements ;
- le traitement analytique des valeurs censurées ;
- les mesures nécessaires dans Power BI.

Cette phase s'appuiera sur le modèle analytique déjà validé afin que les KPI soient construits sur des grains, relations et règles de qualité explicitement documentés.

➡️ **[Consulter le schéma analytique avant la phase BI](schema_analytics/schema_analytics.md)**
