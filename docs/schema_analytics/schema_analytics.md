# Schéma analytique du pipeline Hub'Eau

## 1. Objectif

Ce document présente l'architecture de transformation des données du projet Hub'Eau, depuis la couche de staging jusqu'au modèle analytique final.

Il documente notamment :

- les dépendances entre les modèles dbt ;
- le grain métier de chaque modèle ;
- les clés utilisées pour identifier et relier les données ;
- les relations et cardinalités entre les tables analytiques ;
- le rôle de la table de pont dans la relation plusieurs-à-plusieurs entre les prélèvements et les réseaux.

L'objectif est de rendre explicites les choix de modélisation réalisés avant l'exploitation des données dans Power BI.

---

## 2. Flux de transformation dbt

```mermaid
flowchart TB

    %% =========================================================
    %% STAGING
    %% =========================================================

    STG["<b>STG — stg_resultats_dis</b><br/>
    Grain : 1 résultat brut retourné par l'API<br/>
    19 923 lignes"]

    %% =========================================================
    %% ODS
    %% =========================================================

    PREL["<b>ODS — int_prelevements</b><br/>
    Grain : 1 prélèvement<br/>
    Clé : code_prelevement<br/>
    1 914 lignes"]

    RES["<b>ODS — int_resultats</b><br/>
    Grain : 1 résultat × paramètre × lieu d'analyse<br/>
    Clé composite : code_prelevement<br/>
    + code_parametre + code_lieu_analyse<br/>
    19 923 lignes"]

    PR["<b>ODS — int_prelevements_reseaux</b><br/>
    Grain : 1 association prélèvement × réseau<br/>
    Clé composite : code_prelevement + code_reseau<br/>
    5 197 lignes"]

    %% =========================================================
    %% DIMENSIONS
    %% =========================================================

    DATE["<b>DIM — dim_date</b><br/>
    Clé : date"]

    GEO["<b>DIM — dim_geographie</b><br/>
    Clé : code_commune"]

    INST["<b>DIM — dim_installation</b><br/>
    Clé : code_installation_amont"]

    PARAM["<b>DIM — dim_parametre</b><br/>
    Clé : code_parametre"]

    RESEAU["<b>DIM — dim_reseau</b><br/>
    Clé : code_reseau"]

    %% =========================================================
    %% FACTS / BRIDGE
    %% =========================================================

    FACTP["<b>FACT — fact_prelevements</b><br/>
    Grain : 1 prélèvement<br/>
    Clé : code_prelevement<br/>
    1 914 lignes"]

    FACTR["<b>FACT — fact_resultats</b><br/>
    Grain : 1 résultat × paramètre × lieu d'analyse<br/>
    Clé composite : code_prelevement<br/>
    + code_parametre + code_lieu_analyse<br/>
    19 923 lignes"]

    BRIDGE["<b>BRIDGE — bridge_prelevements_reseaux</b><br/>
    Grain : 1 association prélèvement × réseau<br/>
    Clé composite : code_prelevement + code_reseau<br/>
    5 197 lignes"]

    %% =========================================================
    %% DEPENDANCES DBT
    %% =========================================================

    STG --> PREL
    STG --> RES
    STG --> PR

    PREL --> DATE
    PREL --> GEO
    PREL --> INST
    PREL --> FACTP
    PREL --> FACTR

    RES --> PARAM
    RES --> FACTR

    PR --> BRIDGE

    STG --> RESEAU
```

### Lecture du diagramme

La couche **STG** conserve les données issues du RAW sans modifier leur grain.

La couche **ODS** sépare ensuite trois objets métier :

- les prélèvements ;
- les résultats d'analyse ;
- les associations entre prélèvements et réseaux.

Cette séparation permet de construire les dimensions et tables de faits sans introduire de duplication artificielle.

Les flèches de ce premier diagramme représentent les **dépendances de transformation dbt** entre les modèles. Elles ne représentent pas encore les relations PK/FK du futur modèle Power BI.
