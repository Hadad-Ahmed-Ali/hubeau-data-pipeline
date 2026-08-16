# Documentation de la source — API Hub'Eau

## 1. Présentation

Ce projet utilise l'API **Hub'Eau — Qualité de l'eau potable** comme source de données.

L'objectif du pipeline est d'extraire les données depuis l'API, de réaliser une préparation technique légère avec Python, puis de les charger dans une couche **RAW** destinée à être exploitée ultérieurement dans **BigQuery** et transformée avec **dbt**.

L'architecture cible du projet est la suivante :

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
     ├── STG
     │
     ├── ODS
     │
     └── DIM / FACT
              │
              ▼
      Outil de visualisation
```

---

## 2. Endpoint utilisé

L'extraction Python utilise l'endpoint :

```text
qualite_eau_potable/resultats_dis
```

Cet endpoint fournit les résultats des analyses réalisées sur les prélèvements d'eau distribuée.

L'URL de base utilisée par le pipeline est :

```text
https://hubeau.eaufrance.fr/api/v1/qualite_eau_potable/resultats_dis
```

---

## 3. Périmètre actuel

Pour la première version du pipeline, l'extraction est volontairement limitée à un périmètre simple afin de construire, comprendre et tester l'architecture.

Les paramètres actuellement utilisés sont :

| Paramètre | Valeur | Description |
|---|---:|---|
| `code_commune` | `45234` | Orléans |
| `code_parametre` | `1340` | Nitrates |

Une requête correspond donc conceptuellement à :

```text
resultats_dis
    │
    ├── code_commune = 45234
    │
    └── code_parametre = 1340
```

Le pipeline n'a cependant pas vocation à rester limité à ce périmètre.

Les fonctions Python ont été conçues pour recevoir `code_commune` et `code_parametre` comme paramètres, ce qui permettra par la suite d'étendre l'extraction à d'autres communes ou paramètres de qualité de l'eau.

---

## 4. Structure d'une observation

Chaque observation retournée par l'API correspond à un résultat d'analyse et contient plusieurs catégories d'informations.

### 4.1 Identification du prélèvement

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

Ces informations pourront notamment être utilisées lors de la future construction des dimensions géographiques.

### 4.3 Paramètre analysé

Exemples :

- `code_parametre`
- `code_parametre_se`
- `code_parametre_cas`
- `libelle_parametre`
- `code_type_parametre`

Dans le périmètre actuel :

```text
code_parametre = 1340
```

correspond aux **nitrates**.

### 4.4 Résultat de l'analyse

Les principaux champs sont notamment :

- `resultat_alphanumerique`
- `resultat_numerique`
- `code_unite`
- `libelle_unite`
- `limite_qualite_parametre`

Exemple :

```text
resultat_numerique = 3.5
libelle_unite      = mg/L
```

`resultat_numerique` constitue une mesure qui pourra être utilisée dans la future modélisation analytique.

### 4.5 Informations temporelles

Le champ principal est :

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

Ces informations pourront être exploitées ultérieurement lors de la modélisation.

---

## 5. Gestion de la pagination

L'API ne renvoie pas nécessairement tous les résultats dans une seule réponse.

La réponse contient notamment un attribut :

```text
next
```

qui indique l'URL permettant de récupérer la page suivante.

Le fonctionnement général est le suivant :

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

Le module Python suit donc automatiquement l'URL contenue dans `next` jusqu'à ce que sa valeur soit `None`.

Cette logique permet de récupérer l'ensemble des observations correspondant aux paramètres demandés, indépendamment du nombre de pages retournées par l'API.

Le volume de données n'est donc pas considéré comme une valeur fixe : il peut évoluer lorsque de nouvelles analyses sont publiées dans la source.

---

## 6. Préparation des données avec Python

Une fois toutes les pages récupérées, les observations JSON sont regroupées puis converties en **DataFrame pandas**.

Le principe est :

```text
Réponses JSON
      │
      ▼
Liste de dictionnaires Python
      │
      ▼
DataFrame pandas
      │
      ▼
hub_raw
```

La couche Python réalise volontairement **peu de transformations**.

L'objectif est de rester proche des données sources avant leur chargement dans la future couche RAW de BigQuery.

### Conversion de la date

Le champ :

```text
date_prelevement
```

est converti vers un type datetime UTC avec pandas.

Les valeurs retournées par l'API utilisent notamment un format de type :

```text
2026-05-11T13:59:00Z
```

Le `Z` indique que l'heure est exprimée en UTC.

Cette conversion permet d'obtenir une colonne pandas de type :

```text
datetime64[ns, UTC]
```

---

## 7. Cas particulier : `reseaux`

Le champ `reseaux` possède une structure différente des colonnes classiques.

Une cellule peut contenir une **liste de plusieurs dictionnaires**.

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

La structure est donc imbriquée :

```text
reseaux
   │
   ▼
 liste
   │
   ├── dictionnaire
   │      ├── code
   │      ├── nom
   │      └── debit (optionnel)
   │
   └── dictionnaire
          ├── code
          ├── nom
          └── debit (optionnel)
```

Ce champ n'est volontairement **pas aplati dans la couche d'ingestion Python**.

Sa transformation sera étudiée lors de la modélisation des données afin de conserver une séparation claire entre :

```text
Ingestion
    ↓
Stockage RAW
    ↓
Transformation
    ↓
Modélisation
```

Cette approche permet de préserver autant que possible la structure de la donnée source dans la couche RAW.

---

## 8. Contrôles et tests automatisés

Le projet contient des tests automatisés utilisant **pytest**.

Ils sont stockés dans :

```text
tests/
└── test_hubeau_api.py
```

À ce stade, trois comportements principaux sont testés.

### 8.1 Construction du DataFrame RAW

Le test :

```python
test_build_raw_dataframe()
```

vérifie notamment :

- que la fonction retourne bien un DataFrame pandas ;
- que les observations sont correctement présentes ;
- que `code_commune` est conservé ;
- que `code_parametre` est conservé ;
- que `date_prelevement` est converti vers un type datetime.

### 8.2 Ingestion de l'API

Le test :

```python
test_fetch_hubeau_data()
```

vérifie le comportement de la fonction d'ingestion.

L'appel HTTP réel est remplacé par une réponse simulée afin que le test ne dépende pas :

- de la connexion Internet ;
- de la disponibilité de l'API ;
- du volume de données actuellement présent dans Hub'Eau.

### 8.3 Pagination

Le test :

```python
test_fetch_hubeau_data_pagination()
```

simule plusieurs pages :

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

Le test vérifie ensuite que les observations des différentes pages sont correctement regroupées.

### 8.4 Exécution des tests

Depuis la racine du projet, les tests peuvent être exécutés avec :

```bash
python -m pytest tests/ -v
```

Un résultat valide doit indiquer que l'ensemble des tests est passé avec succès.

---

## 9. Séparation des responsabilités

Le projet cherche à séparer clairement l'exploration, le code d'ingestion et les tests.

La structure actuelle est notamment organisée de la manière suivante :

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
│   └── run_ingestion.py
│
├── tests/
│   └── test_hubeau_api.py
│
├── docs/
│   └── api_hubeau.md
│
├── requirements.txt
├── README.md
└── .gitignore
```

Les responsabilités sont séparées comme suit :

| Élément | Responsabilité |
|---|---|
| `notebooks/` | Exploration et compréhension de la donnée |
| `src/ingestion/` | Logique réutilisable d'extraction et de préparation |
| `src/run_ingestion.py` | Point d'entrée du pipeline d'ingestion |
| `tests/` | Tests automatisés |
| `docs/` | Documentation technique |
| `requirements.txt` | Dépendances Python |
| `README.md` | Présentation générale du projet |

---

## 10. Architecture cible

La partie Python constitue la première brique d'un pipeline plus large.

L'architecture cible est :

```text
                 API Hub'Eau
                      │
                      ▼
              Ingestion Python
                      │
                      ▼
                BigQuery RAW
                      │
                      ▼
                     dbt
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
         STG         ODS      DIM / FACT
                                  │
                                  ▼
                         Visualisation / BI
```

Le rôle de Python est principalement de :

1. interroger l'API ;
2. gérer la pagination ;
3. récupérer les observations ;
4. réaliser la préparation technique minimale ;
5. préparer les données pour leur chargement dans BigQuery.

Les transformations analytiques et métier seront principalement prises en charge par **dbt**.

---

## 11. Prochaines étapes

Les prochaines étapes prévues pour le projet sont :

1. mettre en place le chargement vers **BigQuery** ;
2. créer et alimenter la couche **RAW** ;
3. connecter **dbt** à BigQuery ;
4. construire les modèles de staging (**STG**) ;
5. construire la couche **ODS** ;
6. concevoir les dimensions et tables de faits ;
7. ajouter les tests de qualité de données avec dbt ;
8. documenter les modèles ;
9. préparer les données pour leur exploitation dans un outil de visualisation.

L'objectif final est de disposer d'un pipeline structuré, testable et documenté allant de la source API jusqu'à une couche analytique exploitable.
