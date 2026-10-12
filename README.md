# Hub'Eau Data Pipeline - Analyse de la qualité de l'eau potable

**Auteur : Hadad Ahmed**

**Projet personnel de Data Analytics Engineering** portant sur la conception d'un pipeline de données à partir de l'**API publique Hub'Eau - Qualité de l'eau potable** : de l'extraction des données à leur analyse et leur restitution dans **Power BI**, en utilisant **Python, BigQuery, SQL et dbt**.

**Périmètre étudié :** Orléans (code commune `45234`) · 2016-2026 · 12 paramètres physico-chimiques et microbiologiques · 19 923 résultats d'analyse · 1 914 prélèvements.

## 💧 Paramètres de qualité de l'eau étudiés

L'analyse porte sur **12 paramètres de qualité de l'eau potable**, répartis en deux catégories :

- **Paramètres physico-chimiques (10) :** turbidité, température, pH, conductivité, ammonium, nitrites, nitrates, fer, manganèse et chlore libre.
- **Paramètres microbiologiques (2) :** *Escherichia coli* et entérocoques.

Cette sélection permet d'étudier plusieurs dimensions de la qualité de l'eau potable, notamment ses caractéristiques physico-chimiques et la présence d'indicateurs de contamination microbiologique.

## 🎯 Pourquoi ce projet ?

Les analyses de l'eau potable produisent des résultats de nature différente : mesures numériques, résultats inférieurs à un seuil de quantification, valeurs non mesurées, limites et références de qualité. Leur exploitation exige de distinguer **le prélèvement**, **le résultat d'analyse** et **la règle de qualité applicable**.

L'objectif est de transformer ces données publiques en indicateurs fiables et explorables pour répondre à trois questions métier :

1. **Conformité des prélèvements :** quelle proportion des prélèvements respecte les critères de qualité, et comment évolue-t-elle ?
2. **Dépassements :** quels paramètres dépassent les limites ou références de qualité, à quelle fréquence et à quelles périodes ?
3. **Évolution des paramètres :** comment évoluent les valeurs mesurées, en distinguant résultats directs, censurés (`<x`) et non mesurés (`N.M.`) ?

Le rapport suit ce parcours : **conformité globale → identification des dépassements → analyse détaillée des paramètres**.

> **Portée de l'analyse :** les indicateurs décrivent les résultats disponibles dans le périmètre sélectionné. Ils ne constituent pas, à eux seuls, un avis sanitaire global sur l'eau distribuée.

## 📊 Résultat : dashboard Power BI

**Trois pages analytiques réalisées**, avec des filtres par période et, selon la page, par réseau, installation, paramètre et lieu d'analyse.

**[📥 Consulter le rapport Power BI (.pbix)](Power%20BI/dashboard)** · **[📖 Guide d'utilisation du dashboard](Power%20BI/guide_utilisation_dashboard.md)**

### Page 1 - Conformité des prélèvements

**Question métier :** comment évolue la conformité des prélèvements ?

Quatre indicateurs distinguent les **limites** et **références** de qualité, pour les contrôles **bactériologiques** et **physico-chimiques**. Un graphique présente le nombre de prélèvements non conformes et le taux de conformité dans le temps, selon le type de contrôle sélectionné.

![Page 1 - Conformité des prélèvements](Power%20BI/screenshots/page_1_conformite_prelevements.png)

### Page 2 - Dépassements des règles de qualité

**Question métier :** quels paramètres sont concernés par des dépassements, et comment ceux-ci évoluent-ils ?

La page distingue les dépassements de **limites** et de **références** de qualité. Elle permet de comparer les paramètres présentant des dépassements et d'observer leur évolution temporelle. Les taux sont calculés sur les résultats évaluables pour la règle étudiée.

![Page 2 - Dépassements des règles de qualité](Power%20BI/screenshots/page_2_depassements_regles_qualite.png)

### Page 3 - Analyse des paramètres

**Question métier :** comment évoluent les mesures d'un paramètre et quelle est la nature des résultats disponibles ?

Après sélection d'un paramètre, la page distingue **valeurs directes**, **résultats censurés** et **non mesurés**. Elle présente le taux de censure, la médiane, la moyenne et le maximum des **valeurs directes**, puis leur évolution annuelle et celle des résultats censurés.

Les résultats censurés ne sont **pas assimilés à des mesures exactes** ; lorsqu'aucune valeur directe n'est disponible, les statistiques correspondantes ne sont pas affichées comme des valeurs numériques.

![Page 3 - Analyse des paramètres](Power%20BI/screenshots/page_3_analyse_parametres.png)

Pour explorer les filtres, les graphiques et les cas particuliers : **[lire le guide d'utilisation](Power%20BI/guide_utilisation_dashboard.md)**. Pour consulter les règles de calcul, voir les [spécifications fonctionnelles](#-documentation-et-liens-utiles).

## 🔄 Architecture du pipeline

```text
API publique Hub'Eau - resultats_dis
              │
              ▼
Python : extraction de 12 paramètres, pagination, préparation
              │
              ▼
BigQuery RAW : 19 923 résultats, 32 champs
              │
              ▼
dbt Cloud + SQL : transformations (modélisations) et tests
              │
              ├── STG : standardisation légère, grain source conservé
              ├── ODS : prélèvements / résultats / associations réseaux
              └── Modèle analytique : 5 DIM + 2 FACT + 1 BRIDGE
              │
              ▼
BigQuery : tables analytiques matérialisées
              │
              ▼
Power BI : modèle relationnel, DAX, filtres, 3 pages

GitHub : versionnement du code et de la documentation
```

| Étape | Technologies | Rôle |
|---|---|---|
| Extraction | Python, `requests`, `pandas`, API REST | Récupérer les données multiparamètres et gérer la pagination |
| Stockage | Google Cloud, BigQuery | Conserver les données brutes avec un schéma explicite |
| Transformation | SQL, dbt Cloud | Structurer les grains métier, dimensions, faits et table de pont |
| Contrôles | `pytest`, tests dbt | Vérifier l'ingestion, l'unicité des grains et les relations |
| Restitution | Power BI, DAX | Produire les indicateurs et les visualisations interactives |
| Versionnement | Git, GitHub | Suivre les évolutions et documenter les décisions |

**Exécution :** l'ingestion Python est **déclenchée manuellement** ; aucune orchestration quotidienne n'est mise en place à ce stade.

## 💧 Source et périmètre des données

- **Source :** API publique [Hub'Eau - Qualité de l'eau potable](https://hubeau.eaufrance.fr/), endpoint `qualite_eau_potable/resultats_dis`.
- **Zone :** commune d'Orléans (`45234`).
- **Période des observations :** 2016 à 2026.
- **Volume :** 19 923 résultats, regroupés en 1 914 prélèvements.
- **Paramètres (12) :** turbidité, température, pH, conductivité, ammonium, nitrites, nitrates, fer, manganèse, chlore libre, *Escherichia coli* et entérocoques.

Le périmètre géographique est volontairement limité à Orléans pour construire et valider l'architecture avant une éventuelle extension.

## 🧱 Modélisation analytique et choix métier

Les données sont modélisées à **deux grains distincts** :

- **`fact_prelevements` :** une ligne par prélèvement (**1 914**), pour les indicateurs de conformité.
- **`fact_resultats` :** une ligne par résultat d'un paramètre, d'un prélèvement et d'un lieu d'analyse (**19 923**), pour les mesures et les dépassements.

Le modèle comprend **5 dimensions** (`dim_date`, `dim_geographie`, `dim_installation`, `dim_parametre`, `dim_reseau`) et **1 table de pont** (`bridge_prelevements_reseaux`). Cette dernière représente les associations entre prélèvements et réseaux (**5 197 associations pour 6 réseaux**) sans dupliquer les faits.

Trois décisions structurent la fiabilité des analyses :

1. **Préserver les grains :** ne pas confondre le nombre de résultats avec le nombre de prélèvements.
2. **Respecter les résultats censurés :** conserver l'opérateur et le seuil au lieu d'inventer une valeur numérique exacte.
3. **Conserver les règles applicables à chaque observation :** les limites et références de qualité ne sont pas traitées comme des attributs fixes d'un paramètre.

Le filtrage par réseau est également pris en compte dans les mesures DAX portant sur les résultats, sans créer de relation physique ambiguë entre les tables de faits.

➡️ **[Schéma analytique, cardinalités et décisions de modélisation](docs/schema_analytics/schema_analytics.md)**

## ✅ Tests et qualité des données

- **Python / `pytest` :** tests de l'extraction simulée, de la pagination, de la construction du DataFrame et du chargement BigQuery simulé ; **4 tests validés** lors de l'exécution documentée.
- **dbt :** tests `not_null`, `unique`, `relationships` et tests SQL personnalisés sur les grains composites des résultats et des associations prélèvements–réseaux.
- **Validation analytique :** exploration SQL des limites et références de qualité avant leur traduction en indicateurs Power BI.

La couche RAW conserve les **32 champs source**, y compris la structure imbriquée `reseaux`, dont l'éclatement est effectué dans un modèle dbt dédié.

## ▶️ Exécuter l'ingestion

**Prérequis :** Python, dépendances du projet, accès autorisé à Google Cloud/BigQuery et *Application Default Credentials* (ADC). Les droits sur le projet GCP utilisé pour cette démonstration ne sont pas publics.

```bash
git clone https://github.com/Hadad-Ahmed-Ali/hubeau-data-pipeline.git
cd hubeau-data-pipeline
pip install -r requirements.txt
python -m pytest tests/ -v
python src/run_ingestion.py
```

Le chargement utilise `WRITE_TRUNCATE` sur la table RAW configurée : **attention, une exécution remplace son contenu**. Il faut configurer un projet et des permissions BigQuery adaptés avant de lancer le pipeline.

Les transformations sont ensuite exécutées dans l'environnement dbt connecté à BigQuery, par exemple avec `dbt build --select nom_du_modele`.

## 📁 Organisation du dépôt

```text
hubeau-data-pipeline/
├── src/                         # Extraction et chargement Python
├── tests/                       # Tests pytest
├── notebooks/                   # Exploration initiale
├── dbt/
│   ├── models/                  # STG, ODS, dimensions, faits, bridge
│   ├── tests/                   # Tests SQL personnalisés
│   └── docs/                    # Exploration et décisions de modélisation
├── docs/                        # Pipeline et schéma analytique
├── Power BI/
│   ├── dashboard/
│   │   └── dashboard_qualite_eau_potable.pbix
│   ├── screenshots/
│   │   ├── page_1_conformite_prelevements.png
│   │   ├── page_2_depassements_regles_qualite.png
│   │   └── page_3_analyse_parametres.png
│   ├── guide_utilisation_dashboard.md
│   ├── docs/                    # KPI, intégration et spécifications
│   └── queries/                 # Exploration SQL des règles de qualité
├── requirements.txt
└── README.md
```

## 📚 Documentation et liens utiles

**Rapport et utilisation**
- [Rapport Power BI - `dashboard_qualite_eau_potable.pbix`](Power%20BI/dashboard/dashboard_qualite_eau_potable.pbix)
- [Guide d'utilisation du dashboard](Power%20BI/guide_utilisation_dashboard.md)

**Conception Power BI**
- [Réflexion sur les KPI](Power%20BI/docs/reflexion_KPIs.md)
- [Exploration SQL des règles de qualité](Power%20BI/queries/exploration_regles_qualite.sql)
- [Intégration du modèle BigQuery dans Power BI](Power%20BI/docs/integration_modele_bigquery_power_bi.md)
- [Spécification - Page 1 : Conformité des prélèvements](Power%20BI/docs/specification_dashboard/page_1_conformite_prelevements.md)
- [Spécification - Page 2 : Dépassements des règles de qualité](Power%20BI/docs/specification_dashboard/page_2_depassements_regles_qualite.md)
- [Spécification - Page 3 : Analyse des paramètres](Power%20BI/docs/specification_dashboard/page_3_analyse_parametres.md)

**Pipeline et modélisation**
- [Documentation du pipeline](docs/pipeline_hubeau.md)
- [Schéma analytique et décisions de modélisation](docs/schema_analytics/schema_analytics.md)
- [Exploration de la modélisation dbt](dbt/docs/exploration_modelisation_dbt.md)
- [Matrice des décisions de modélisation](dbt/docs/matrice_colonnes_modelisation_dbt.md)
