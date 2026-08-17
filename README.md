## 👤 Auteur

**Hadad Ahmed**

En début de carrière et actuellement en recherche d'emploi dans le domaine de la Data, je développe ce projet personnel de Data Analytics Engineering autour des données publiques sur la qualité de l'eau potable issues de l'API Hub'Eau.

---

## Licence

Ce projet utilise des données publiques provenant de Hub'Eau.

Les conditions d'utilisation et les licences applicables aux données restent celles définies par les producteurs et diffuseurs des données sources.

---

# Hub'Eau Data Pipeline

Pipeline Data Engineering permettant d'extraire les données de qualité de l'eau potable depuis l'API **Hub'Eau**, de les préparer avec **Python**, puis à terme de les charger dans **BigQuery** et de les transformer avec **dbt** afin de construire une couche analytique exploitable pour la visualisation.

> **Statut du projet :** En cours de développement  
> **Étape actuelle :** ingestion Python, pagination, préparation RAW, tests unitaires et documentation de l'API.

---

## Objectif du projet

L'objectif est de construire progressivement un pipeline de données complet autour des données publiques de qualité de l'eau potable.

Le projet suit une logique proche d'un environnement Data Engineering :

```text
API Hub'Eau
     │
     ▼
   Python : Extraction des données + contrôles légers
     │
     ▼
BigQuery : Data Warehouse - Stockage des données RAW et des données modélisées
     │
     ▼
    dbt : Transformation, tests qualité et modélisation SQL
     │
     ├── STG
     ├── ODS
     └── DIM / FACT
              │
              ▼
        POWER BI : Visualisation / tableaux de bord
```

La première étape consiste à construire une ingestion Python capable de :

- interroger l'API Hub'Eau ;
- gérer automatiquement la pagination ;
- récupérer l'ensemble des observations correspondant au périmètre demandé ;
- convertir les données JSON en DataFrame pandas ;
- effectuer une préparation technique légère ;
- tester automatiquement les principales fonctions du pipeline.

Les transformations métier seront volontairement réalisées dans les couches suivantes, principalement avec **dbt**.

---

## Source de données

Le projet utilise l'API publique **Hub'Eau — Qualité de l'eau potable**.

Endpoint actuellement utilisé :

```text
qualite_eau_potable/resultats_dis
```

Il permet de récupérer les résultats des analyses réalisées sur les prélèvements d'eau distribuée.

### Périmètre actuel

La première version du pipeline utilise :

| Paramètre | Valeur | Description |
|---|---:|---|
| `code_commune` | `45234` | Orléans |
| `code_parametre` | `1340` | Nitrates |

Ce périmètre est utilisé pour construire et tester le pipeline. Les fonctions Python sont paramétrables afin de pouvoir étendre ultérieurement l'extraction à d'autres communes et paramètres.

La documentation technique détaillée de la source est disponible dans [`docs/api_hubeau.md`](docs/api_hubeau.md).

---

## Architecture cible

```text
                         ┌─────────────────┐
                         │   API Hub'Eau   │
                         └────────┬────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │     Python      │
                         │   Ingestion     │
                         └────────┬────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │  BigQuery RAW   │
                         └────────┬────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │       dbt       │
                         └────────┬────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    ▼             ▼             ▼
                  STG            ODS        DIM / FACT
                                                  │
                                                  ▼
                                         Visualisation / BI
```

Cette architecture permet de séparer les différentes responsabilités :

**Python** → ingestion et préparation technique minimale  
**BigQuery** → stockage des données sources et des données modélisées  
**dbt** → transformation, qualité et modélisation SQL  
**DIM / FACT** → couche analytique  
**BI** → exploitation et visualisation des données

---

## Ingestion Python

Le code d'ingestion se trouve dans :

```text
src/ingestion/hubeau_api.py
```

Le module contient la logique permettant de récupérer les données Hub'Eau et de construire le DataFrame RAW.

Le point d'entrée du pipeline est :

```text
src/run_ingestion.py
```

### Gestion de la pagination

L'API peut retourner les résultats sur plusieurs pages.

Le pipeline suit automatiquement la propriété `next` retournée par Hub'Eau :

```text
Page 1
   │
   └── next
          │
          ▼
       Page 2
          │
          └── next
                 │
                 ▼
                ...
                 │
                 ▼
        Dernière page
                 │
                 └── next = None
```

L'ingestion n'est donc pas limitée au contenu de la première page.

---

## Préparation des données

Après extraction, les observations JSON sont converties en DataFrame pandas :

```text
API
 │
 ▼
JSON
 │
 ▼
Liste de dictionnaires
 │
 ▼
DataFrame pandas
 │
 ▼
hub_raw
```

La préparation Python reste volontairement légère afin de préserver au maximum les données sources avant leur chargement dans la future couche RAW.

Le champ `date_prelevement` est notamment converti en datetime UTC.

### Champ imbriqué `reseaux`

Le champ `reseaux` contient une structure imbriquée de type :

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

Cette structure n'est volontairement pas aplatie pendant l'ingestion.

Son traitement sera étudié dans les couches de transformation et de modélisation.

---

## Tests

Les tests automatisés sont réalisés avec **pytest** et se trouvent dans :

```text
tests/test_hubeau_api.py
```

Les tests actuels vérifient notamment :

- la construction du DataFrame RAW ;
- la conversion de `date_prelevement` ;
- la récupération des données avec une réponse API simulée ;
- la gestion de la pagination.

Les appels HTTP sont simulés dans les tests unitaires afin de ne pas dépendre de la disponibilité réelle de l'API.

Pour exécuter l'ensemble des tests :

```bash
python -m pytest tests/ -v
```

État actuel :

```text
3 tests passed
```

---

## Structure du repository actuelle mais peut évoluer dans l'avenir

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

### Rôle des dossiers

| Élément | Rôle |
|---|---|
| `notebooks/` | Exploration et compréhension des données |
| `src/` | Code Python du pipeline |
| `src/ingestion/` | Extraction et préparation des données |
| `tests/` | Tests automatisés |
| `docs/` | Documentation technique |
| `requirements.txt` | Dépendances Python |
| `.gitignore` | Fichiers exclus du versionnement |

---

## Installation

### 1. Cloner le repository

```bash
git clone https://github.com/Hadad-Ahmed-Ali/hubeau-data-pipeline.git
```

Puis :

```bash
cd hubeau-data-pipeline
```

### 2. Installer les dépendances

```bash
pip install -r requirements.txt
```

Les principales dépendances actuelles sont :

- `requests`
- `pandas`
- `pytest`

---

## Exécuter l'ingestion

Depuis la racine du projet :

```bash
python src/run_ingestion.py
```

Le pipeline :

1. appelle l'API Hub'Eau ;
2. récupère les différentes pages ;
3. regroupe les observations ;
4. construit le DataFrame RAW ;
5. convertit la date de prélèvement.

À ce stade du projet, les données sont conservées en mémoire. Le chargement vers BigQuery constitue la prochaine grande étape du pipeline.

---

## Exécuter les tests

Depuis la racine du repository :

```bash
python -m pytest tests/ -v
```

Les tests unitaires permettent de vérifier le comportement du code indépendamment de l'état réel de l'API Hub'Eau.

---

## Technologies

| Technologie | Utilisation |
|---|---|
| Python | Ingestion et préparation des données |
| requests | Appels HTTP vers l'API |
| pandas | Manipulation et préparation des données |
| pytest | Tests unitaires |
| Git / GitHub | Versionnement et documentation |
| BigQuery | Data warehouse — prévu |
| dbt | Transformation et modélisation — prévu |
| BI | Visualisation — prévue |

---

## Roadmap

### Phase 1 — Exploration et ingestion Python

- [x] Étudier l'API Hub'Eau
- [x] Tester l'endpoint `resultats_dis`
- [x] Comprendre la structure JSON
- [x] Identifier la structure imbriquée `reseaux`
- [x] Implémenter la pagination
- [x] Construire le DataFrame RAW
- [x] Convertir les dates
- [x] Structurer le code Python
- [x] Ajouter les tests unitaires
- [x] Documenter la source API

### Phase 2 — BigQuery

- [x] Configurer l'environnement GCP
- [ ] Créer le dataset RAW
- [ ] Définir le schéma de stockage
- [ ] Charger les données dans BigQuery
- [ ] Sécuriser et fiabiliser le chargement

### Phase 3 — dbt

- [x] Initialiser le projet dbt
- [ ] Déclarer les sources RAW
- [ ] Construire les modèles STG
- [ ] Construire la couche ODS
- [ ] Concevoir les dimensions
- [ ] Concevoir les tables de faits
- [ ] Ajouter les tests dbt
- [ ] Générer la documentation dbt

### Phase 4 — Analytics / BI

- [ ] Définir les KPI
- [ ] Connecter l'outil de visualisation
- [ ] Construire les visualisations
- [ ] Documenter les indicateurs

---

## Documentation

La documentation technique détaillée est disponible dans :

- [`docs/api_hubeau.md`](docs/api_hubeau.md) — fonctionnement de l'API, structure des données, pagination, préparation Python et tests ;
- [`notebooks/01_exploration_hubeau.ipynb`](notebooks/01_exploration_hubeau.ipynb) — exploration initiale et compréhension progressive de la source.

---

## Principes du projet

Ce projet est construit autour de quelques principes Data Engineering :

- séparer l'exploration du code de production ;
- conserver une couche RAW proche de la source ;
- rendre le code d'ingestion réutilisable ;
- automatiser les contrôles avec des tests ;
- séparer ingestion et transformation ;
- documenter les choix techniques ;
- construire progressivement une architecture reproductible et maintenable.

---
