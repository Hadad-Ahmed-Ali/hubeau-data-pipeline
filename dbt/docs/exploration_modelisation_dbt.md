# Exploration préalable à la modélisation Hub'Eau

## 1. Objectif

Avant de construire les modèles dbt, une exploration de la table RAW a été réalisée afin de comprendre :

- le grain actuel des données ;
- la cardinalité des principales colonnes ;
- les relations entre prélèvements et analyses ;
- la structure particulière du champ imbriqué `reseaux` ;
- les risques de duplication liés à l'utilisation de `UNNEST()` ;
- les premières entités susceptibles d'intervenir dans le futur modèle décisionnel.

Cette étape précède volontairement l'écriture des modèles SQL.

L'objectif est de suivre la démarche :

```text
Comprendre les données
        ↓
Identifier le grain
        ↓
Étudier les relations
        ↓
Profiler les colonnes
        ↓
Concevoir STG / ODS
        ↓
Concevoir DIM / FACT
        ↓
Définir les KPI
```

---

# 2. Table RAW étudiée

La table étudiée est :

```text
project-3665c0d5-5952-473b-82e.hubeau_raw.resultats_dis_raw
```

Elle provient de l'endpoint Hub'Eau :

```text
qualite_eau_potable/resultats_dis
```

Le périmètre actuel de l'extraction est :

```text
code_commune   = 45234  → Orléans
code_parametre = 1340   → Nitrates
```

La table contient actuellement :

```text
311 lignes
32 champs
```
On peut déjà organiser les 32 champs en grands groupes :

| Groupe                | Colonnes principales                                                                                     | Rôle potentiel                         |
| --------------------- | -------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| Géographie            | `code_departement`, `nom_departement`, `code_commune`, `nom_commune`                                     | axes géographiques                     |
| Prélèvement / analyse | `code_prelevement`, `reference_analyse`, `date_prelevement`, `code_lieu_analyse`                         | identification de l'événement analysé  |
| Paramètre             | `code_parametre`, `code_parametre_se`, `code_parametre_cas`, `libelle_parametre*`, `code_type_parametre` | substance/paramètre mesuré             |
| Résultat              | `resultat_numerique`, `resultat_alphanumerique`, `code_unite`, `libelle_unite`                           | mesure                                 |
| Seuils qualité        | `limite_qualite_parametre`, `reference_qualite_parametre`                                                | comparaison/interprétation du résultat |
| Conformité            | `conclusion_conformite_prelevement`, les 4 champs `conformite_*`                                         | qualité/conformité                     |
| Acteurs               | `nom_uge`, `nom_distributeur`, `nom_moa`                                                                 | organisation / gestion                 |
| Installation          | `code_installation_amont`, `nom_installation_amont`                                                      | infrastructure                         |
| Réseaux               | `reseaux`                                                                                                | relation imbriquée potentiellement 1→N |


Le volume peut évoluer lors des prochaines exécutions du pipeline.

---

# 3. Grain observé de la table RAW

Une première analyse a comparé :

- le nombre de lignes ;
- le nombre de `reference_analyse` distinctes ;
- le nombre de `code_prelevement` distincts ;
- le nombre de paramètres ;
- le nombre de communes.

Résultat :

| Indicateur | Nombre |
|---|---:|
| Lignes | 311 |
| `reference_analyse` distinctes | 311 |
| `code_prelevement` distincts | 311 |
| `code_parametre` distincts | 1 |
| `code_commune` distincts | 1 |

Une recherche des `code_prelevement` apparaissant plusieurs fois n'a retourné aucune ligne.

Dans **le périmètre actuel**, on observe donc :

```text
1 ligne RAW
    │
    ├── 1 code_prelevement
    ├── 1 reference_analyse
    ├── 1 paramètre : nitrate
    └── 1 résultat d'analyse
```

Le grain observé peut être formulé ainsi :

> Une ligne représente actuellement un résultat d'analyse du paramètre nitrate associé à un prélèvement donné pour la commune d'Orléans.

### Point de vigilance

Ce grain est **observé sur le périmètre actuel** et ne doit pas encore être considéré comme une règle générale de l'API Hub'Eau.

L'extraction étant filtrée sur un seul paramètre :

```text
code_parametre = 1340
```

il reste possible qu'un même prélèvement soit associé à plusieurs lignes lorsque plusieurs paramètres sont extraits.

Cette hypothèse devra être vérifiée si le périmètre du pipeline est élargi.

---

# 4. Première classification des champs RAW

Les 32 champs peuvent être regroupés conceptuellement de la manière suivante.

## Géographie

```text
code_departement
nom_departement
code_commune
nom_commune
```

## Prélèvement / analyse

```text
code_prelevement
reference_analyse
date_prelevement
code_lieu_analyse
```

## Paramètre analysé

```text
code_parametre
code_parametre_se
code_parametre_cas
libelle_parametre
libelle_parametre_maj
libelle_parametre_web
code_type_parametre
```

## Résultat

```text
resultat_alphanumerique
resultat_numerique
code_unite
libelle_unite
```

## Limites et références de qualité

```text
limite_qualite_parametre
reference_qualite_parametre
```

## Conformité

```text
conclusion_conformite_prelevement
conformite_limites_bact_prelevement
conformite_limites_pc_prelevement
conformite_references_bact_prelevement
conformite_references_pc_prelevement
```

## Acteurs / gestion

```text
nom_uge
nom_distributeur
nom_moa
```

## Installation

```text
code_installation_amont
nom_installation_amont
```

## Réseaux

```text
reseaux
```

Le champ `reseaux` nécessite une analyse spécifique car il possède le type BigQuery :

```text
ARRAY<STRUCT<
    code STRING,
    nom STRING,
    debit STRING
>>
```

---

# 5. Cardinalité des principales entités

Une première analyse de cardinalité a donné :

| Élément | Nombre de valeurs distinctes |
|---|---:|
| Lignes | 311 |
| `code_prelevement` | 311 |
| `reference_analyse` | 311 |
| Département | 1 |
| Commune | 1 |
| Paramètre | 1 |
| `code_parametre_se` | 1 |
| `code_parametre_cas` | 1 |
| Type de paramètre | 1 |
| Unité | 1 |
| UGE | 2 |
| Distributeur | 2 |
| MOA | 2 |
| Installation amont | 4 |
| Lieu d'analyse | 1 |

Cette exploration montre que le périmètre actuel est volontairement restreint :

```text
311 analyses
     │
     ├── 1 département
     ├── 1 commune
     ├── 1 paramètre
     ├── 1 unité
     ├── 1 lieu d'analyse
     ├── 2 UGE
     ├── 2 distributeurs
     ├── 2 MOA
     └── 4 installations amont
```

Ces cardinalités ne suffisent cependant pas à décider qu'un champ doit devenir une dimension.

La conception DIM / FACT devra également tenir compte :

- de la signification métier ;
- du grain ;
- des relations entre les entités ;
- des futurs axes d'analyse ;
- des KPI recherchés ;
- de l'extension future du périmètre.

---

# 6. Exploration du champ `reseaux`

Le champ `reseaux` est un tableau de structures imbriquées.

Une analyse du nombre d'éléments présents dans chaque array a donné :

| Situation | Nombre d'analyses |
|---|---:|
| Aucun élément réseau | 0 |
| Un seul élément réseau | 0 |
| Plusieurs éléments réseau | 311 |
| Maximum observé | 7 éléments |

Toutes les analyses actuelles possèdent donc plusieurs éléments dans `reseaux`.

---

# 7. Risque lié à `UNNEST(reseaux)`

L'application directe de :

```sql
UNNEST(reseaux)
```

sur la table RAW produit :

```text
1 837 relations
```

à partir des :

```text
311 analyses
```

La table passerait donc conceptuellement de :

```text
1 ligne = 1 résultat d'analyse
```

à :

```text
1 ligne = 1 résultat d'analyse × 1 élément réseau
```

Cela entraînerait la répétition des mesures de l'analyse.

Par exemple :

```text
Analyse A
resultat_numerique = 5.2

Réseau 1 → 5.2
Réseau 2 → 5.2
Réseau 3 → 5.2
```

Une agrégation naïve comme :

```sql
AVG(resultat_numerique)
```

sur les données éclatées pourrait alors surpondérer les analyses associées à davantage d'éléments réseau.

### Première règle de modélisation

> Ne pas modifier le grain de la table principale des résultats d'analyse en faisant directement un `UNNEST(reseaux)` sans isoler la relation avec les réseaux.

---

# 8. Nombre réel de réseaux

Les 1 837 éléments imbriqués ne correspondent pas à 1 837 réseaux différents.

L'exploration a identifié seulement :

```text
5 code_reseau distincts
```

Le nombre important d'éléments s'explique notamment par la présence de plusieurs libellés pour un même code réseau.

Exemple :

```text
045000474
├── ORLEANS
├── ORLEANS-ST JEAN LE BLANC-ST PRYVÉ
└── ORLEANS-ST JEAN LE BLANC-ST PRYVÉ-ST DENIS EN VAL
```

Autre exemple :

```text
045000513
├── ST DENIS EN VAL
└── SAINT DENIS EN VAL
```

Et :

```text
045000525
├── ST JEAN LE BLANC
└── ST JEAN LE BLANC(ABA)
```

Le champ :

```text
code_reseau
```

apparaît donc comme un identifiant plus stable que `nom_reseau`.

Cette observation devra être prise en compte lors de la conception d'une éventuelle dimension réseau.

---

# 9. Réseaux distincts par analyse

Après déduplication sur `code_reseau`, la distribution est :

| Nombre de codes réseau distincts par analyse | Nombre d'analyses |
|---:|---:|
| 1 | 34 |
| 2 | 84 |
| 3 | 193 |
| **Total** | **311** |

Une analyse est donc actuellement associée à :

```text
1 à 3 codes réseau distincts
```

et non réellement à sept réseaux différents.

Les sept éléments observés dans certains arrays proviennent notamment de plusieurs représentations d'un même code réseau.

La structure conceptuelle commence donc à apparaître comme :

```text
ANALYSE
   │
   │ 1..N
   ▼
RELATION ANALYSE ↔ RÉSEAU
   │
   ▼
RÉSEAU
```

La modélisation définitive de cette relation reste à concevoir.

---

# 10. Exploration du débit réseau

Le champ :

```text
reseaux.debit
```

a également été étudié.

Pour le réseau :

```text
045000474
```

plusieurs valeurs sont observées :

```text
48 %
4 %
valeur vide
```

Les valeurs `48 %` et `4 %` coexistent entre 2016 et 2025.

Exemple de comportement observé :

```text
2016 → 48 % et 4 %
2017 → 48 % et 4 %
...
2025 → 48 % et 4 %
2026 → 48 %, 4 % et valeur vide
```

Le débit n'est donc pas simplement une valeur qui aurait changé une fois dans le temps.

### Conséquence pour la modélisation

`debit_reseau` ne doit pas être considéré, à ce stade, comme un attribut fixe du réseau.

Une structure de type :

```text
dim_reseau
├── code_reseau
├── nom_reseau
└── debit_reseau
```

risquerait d'être incorrecte puisqu'un même `code_reseau` possède plusieurs valeurs de débit.

Le débit semble davantage dépendre du contexte de l'association retournée par Hub'Eau.

Sa place définitive devra être déterminée lors de la conception des modèles intermédiaires.

---

# 11. Première représentation conceptuelle

À ce stade de l'exploration, les données suggèrent la distinction suivante :

```text
                    RÉSULTAT D'ANALYSE
                           │
                           │
              ┌────────────┴────────────┐
              │                         │
              ▼                         ▼
       informations                association
       de l'analyse                 aux réseaux
                                        │
                                        ▼
                                   CODE RÉSEAU
```

Une architecture dbt potentielle pourrait donc séparer :

```text
RAW
resultats_dis_raw
       │
       ├──────────────────────┐
       ▼                      ▼
résultats d'analyse     relations analyse-réseau
       │                      │
       ▼                      ▼
grain analyse          grain analyse × réseau
```

Cette architecture est encore une **piste de conception**, et non un modèle définitif.

Elle devra être confrontée à l'analyse des autres colonnes et aux futurs besoins analytiques.

---

# 12. Points établis à ce stade

Les éléments suivants peuvent désormais être considérés comme établis pour le jeu de données actuel :

1. La table RAW contient 311 lignes et 32 champs.

2. Les 311 lignes possèdent 311 `code_prelevement` distincts.

3. Les 311 lignes possèdent 311 `reference_analyse` distinctes.

4. Le périmètre actuel contient une commune et un paramètre.

5. Le grain actuellement observé est celui d'un résultat nitrate associé à un prélèvement.

6. Toutes les analyses contiennent plusieurs éléments dans `reseaux`.

7. `UNNEST(reseaux)` produit 1 837 éléments à partir de 311 analyses.

8. Ces 1 837 éléments ne représentent que 5 `code_reseau` distincts.

9. Une même analyse est associée à 1, 2 ou 3 codes réseau distincts après déduplication.

10. Un même `code_reseau` peut posséder plusieurs variantes de `nom_reseau`.

11. `code_reseau` apparaît plus stable que `nom_reseau` pour identifier un réseau.

12. `debit_reseau` n'est pas un attribut fixe d'un réseau.

13. Le réseau ne doit pas être ajouté naïvement au grain de la future table principale des résultats.

---

# 13. Points qui restent à étudier

L'exploration n'est pas encore terminée.

Avant de concevoir les modèles dbt, il reste notamment à étudier :

```text
NULL / valeurs vides
        ↓
Résultats numériques et alphanumériques
        ↓
Unités
        ↓
Limites et références de qualité
        ↓
Champs de conformité
        ↓
UGE / distributeur / MOA
        ↓
Installations amont
        ↓
Relations entre ces entités
        ↓
Évolution temporelle
```

Il faudra également déterminer pour chaque champ :

| Question | Objectif |
|---|---|
| Que représente-t-il ? | Compréhension métier |
| Est-il renseigné ? | Qualité |
| Est-il stable ? | Fiabilité |
| Doit-il être renommé ? | STG |
| Doit-il être transformé ? | STG / ODS |
| Constitue-t-il une entité ? | ODS / DIM |
| Constitue-t-il une mesure ? | FACT |
| Peut-il servir d'axe d'analyse ? | DIM / BI |
| Peut-il contribuer à un KPI ? | Analytics |

---

# 14. Prochaine étape

La prochaine étape de l'exploration consistera à profiler les autres colonnes, en particulier :

- les valeurs nulles ;
- les valeurs vides ;
- les résultats ;
- les informations de conformité ;
- les seuils de qualité ;
- les acteurs et installations.

À l'issue de cette exploration, une matrice de conception pourra être construite :

```text
Colonne RAW
    │
    ├── signification
    ├── type
    ├── cardinalité
    ├── qualité
    ├── traitement STG
    ├── traitement ODS
    ├── utilisation DIM / FACT
    └── intérêt potentiel pour les KPI
```

Cette matrice servira de base à la construction du premier modèle :

```text
stg_resultats_dis
```

puis des modèles intermédiaires et du modèle décisionnel.

---

## État de l'exploration

```text
Compréhension générale de la RAW       ✅
Analyse du grain actuel                ✅
Analyse de reseaux                     ✅
Analyse des cardinalités principales   ✅

Profil des NULL / valeurs vides        ⏳
Analyse des résultats                  ⏳
Analyse de la conformité               ⏳
Analyse des acteurs / installations    ⏳
Matrice des 32 champs                  ⏳

Conception STG                         À venir
Conception ODS                         À venir
Conception DIM / FACT                  À venir
Définition des KPI                     À venir
```
