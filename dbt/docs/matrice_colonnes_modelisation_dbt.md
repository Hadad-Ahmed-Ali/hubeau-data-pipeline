# Matrice de conception des colonnes Hub'Eau

## 1. Objectif

Ce document formalise les décisions de conception prises pour les 32 champs de la table RAW :

```text
project-3665c0d5-5952-473b-82e.hubeau_raw.resultats_dis_raw
```

Il fait suite à l'exploration documentée dans :

```text
dbt/docs/exploration_modelisation_dbt.md
```

L'exploration a permis de comprendre :

- le grain actuel des données ;
- les cardinalités ;
- la complétude des colonnes ;
- la représentation des résultats ;
- les limites et informations de conformité ;
- les acteurs et installations ;
- la structure imbriquée du champ `reseaux`.

Le présent document transforme ces observations en **décisions de modélisation**.

La démarche suivie est :

```text
Exploration de la RAW
        ↓
Compréhension des champs
        ↓
Matrice de conception
        ↓
Contrat STG
        ↓
Conception ODS
        ↓
Conception DIM / FACT
        ↓
KPI / Datavisualisation
```

Le périmètre actuel reste :

```text
code_commune   = 45234  → Orléans
code_parametre = 1340   → Nitrates
```

Les décisions doivent néanmoins éviter, autant que possible, de dépendre uniquement de ce périmètre restreint.

---

# 2. Principes de conception retenus

## 2.1 Préserver le grain dans STG

Le grain actuellement observé est :

> Une ligne représente un résultat d'analyse du paramètre nitrate associé à un prélèvement donné.

Le modèle principal de staging devra préserver ce grain.

En particulier, le champ :

```text
reseaux
```

ne devra pas être directement éclaté avec `UNNEST()` dans le modèle principal si cette opération provoque une duplication des résultats.

---

## 2.2 Conserver une représentation fidèle de la source

Le staging a principalement pour rôle de fournir une représentation propre, stable et compréhensible de la donnée source.

Les transformations métier complexes ne doivent pas être ajoutées dans STG sans nécessité.

La logique générale retenue est :

```text
RAW
│
│ données issues de l'API
▼
STG
│
│ représentation fidèle et propre
│ grain préservé
▼
ODS
│
│ transformations métier
│ parsing
│ restructuration
│ déduplication
▼
DIM / FACT
│
│ modèle décisionnel
▼
BI / KPI
```

---

## 2.3 Privilégier les codes métier aux libellés

Lorsque la source fournit un code et un libellé, le code est privilégié comme identifiant métier potentiel.

Cette règle est notamment pertinente pour :

```text
code_commune
code_parametre
code_installation_amont
reseaux.code
```

Les libellés restent des attributs descriptifs.

L'exploration a montré que certains libellés peuvent varier alors que le code reste identique.

---

## 2.4 Ne pas corriger arbitrairement les valeurs manquantes

Une valeur `NULL` ou vide n'est pas automatiquement une anomalie.

Aucune imputation arbitraire de type :

```text
NULL → "INCONNU"
```

ne sera réalisée sans justification métier.

---

## 2.5 Préserver la sémantique des résultats

Les représentations :

```text
resultat_numerique
resultat_alphanumerique
```

doivent toutes les deux être conservées.

En particulier :

```text
resultat_alphanumerique = "<0,5"
resultat_numerique      = 0.0
```

ne signifie pas que la concentration réelle est égale à zéro.

---

## 2.6 Distinguer résultat du paramètre et conformité du prélèvement

Les informations :

```text
conclusion_conformite_prelevement
conformite_*
```

décrivent le prélèvement dans son ensemble.

Elles ne doivent pas être assimilées à une conformité propre au résultat nitrate.

---

# 3. Matrice de conception des 32 champs

## 3.1 Géographie

| Colonne RAW | Type RAW | Qualité / particularité | Décision STG | ODS / DIM potentiel | Intérêt analytique |
|---|---|---|---|---|---|
| `code_departement` | STRING | renseigné, 1 valeur actuellement | conserver tel quel | identifiant géographique potentiel | filtre / regroupement département |
| `nom_departement` | STRING | renseigné, 1 valeur actuellement | conserver tel quel | attribut géographique | affichage BI |
| `code_commune` | STRING | renseigné, 1 valeur actuellement | conserver tel quel | identifiant métier privilégié de la commune | analyse par commune |
| `nom_commune` | STRING | renseigné, 1 valeur actuellement | conserver tel quel | attribut de la commune | affichage BI |

### Décision

Les codes géographiques restent en `STRING`.

Ils ne doivent pas être convertis en nombres puisqu'ils constituent des identifiants et non des mesures.

Une éventuelle dimension géographique sera étudiée lors de la conception DIM / FACT.

---

# 3.2 Prélèvement / analyse

| Colonne RAW | Type RAW | Qualité / particularité | Décision STG | ODS / DIM potentiel | Intérêt analytique |
|---|---|---|---|---|---|
| `code_prelevement` | STRING | 311 valeurs distinctes, renseigné | conserver tel quel | identifiant du prélèvement | comptage / identification des prélèvements |
| `reference_analyse` | STRING | 311 valeurs distinctes, renseigné | conserver tel quel | référence de l'analyse | traçabilité |
| `date_prelevement` | TIMESTAMP | renseigné | conserver le timestamp source | dérivation temporelle ultérieure | analyses temporelles |
| `code_lieu_analyse` | STRING | renseigné, 1 valeur actuellement | conserver tel quel | lieu d'analyse potentiel | filtre / axe éventuel |

### Décision

Les attributs temporels tels que :

```text
année
trimestre
mois
jour
```

ne sont pas créés dans STG.

Ils seront dérivés dans une couche ultérieure si les besoins analytiques le justifient.

La relation entre `code_prelevement` et `reference_analyse` devra être réévaluée si le pipeline est étendu à plusieurs paramètres.

---

# 3.3 Paramètre analysé

| Colonne RAW | Type RAW | Qualité / particularité | Décision STG | ODS / DIM potentiel | Intérêt analytique |
|---|---|---|---|---|---|
| `code_parametre` | STRING | renseigné, 1 valeur actuellement | conserver | identifiant principal potentiel du paramètre | filtre / comparaison par paramètre |
| `code_parametre_se` | STRING | renseigné | conserver | à évaluer avec un périmètre élargi | à déterminer |
| `code_parametre_cas` | STRING | 139 valeurs absentes | conserver les valeurs source et les NULL | à évaluer | à déterminer |
| `libelle_parametre` | STRING | renseigné | conserver | attribut potentiel d'une dimension paramètre | affichage BI |
| `libelle_parametre_maj` | STRING | renseigné | conserver | attribut descriptif à réévaluer | affichage éventuel |
| `libelle_parametre_web` | STRING | 311 valeurs absentes | conserver provisoirement | candidat à exclusion ultérieure | aucun actuellement |
| `code_type_parametre` | STRING | renseigné | conserver | classification potentielle | segmentation éventuelle |

### Décision

La faible cardinalité actuelle ne constitue pas une raison pour supprimer ces champs puisque l'extraction ne porte actuellement que sur un paramètre.

`code_parametre` constitue le candidat naturel pour identifier le paramètre métier.

---

# 3.4 Résultat et unité

| Colonne RAW | Type RAW | Qualité / particularité | Décision STG | Transformation ODS potentielle | Intérêt FACT / KPI |
|---|---|---|---|---|---|
| `resultat_alphanumerique` | STRING | contient notamment des valeurs `<0,5` | conserver tel quel | parsing éventuel opérateur / seuil | interprétation / traçabilité |
| `resultat_numerique` | FLOAT64 | mesure exploitable mais `0.0` pour les `<0,5` | conserver tel quel | traitement des valeurs censurées à définir | mesure quantitative principale |
| `code_unite` | STRING | renseigné | conserver | structuration avec paramètre à évaluer | contrôle des unités |
| `libelle_unite` | STRING | `mg/L` actuellement | conserver | structuration à évaluer | affichage BI |

### Transformation ODS candidate

Pour :

```text
resultat_alphanumerique = "<0,5"
```

une transformation ultérieure pourra éventuellement produire :

```text
operateur_resultat = "<"
seuil_resultat     = 0.5
```

Cette transformation ne sera pas réalisée dans STG.

Aucune substitution arbitraire de `<0,5` par `0`, `0.25` ou `0.5` n'est définie à ce stade.

---

# 3.5 Limites et références de qualité

| Colonne RAW | Type RAW | Qualité / particularité | Décision STG | Transformation ODS potentielle | Intérêt analytique |
|---|---|---|---|---|---|
| `limite_qualite_parametre` | STRING | `<=50 mg/L` sur le périmètre actuel | conserver tel quel | parser opérateur / valeur / unité | dépassement / écart à la limite |
| `reference_qualite_parametre` | STRING | 311 valeurs absentes | conserver provisoirement | réévaluer avec périmètre élargi | aucun actuellement |

### Transformation ODS candidate

La valeur :

```text
<=50 mg/L
```

pourra éventuellement être structurée en :

```text
operateur_limite         = "<="
limite_qualite_numerique = 50.0
unite_limite             = "mg/L"
```

La transformation devra être générique.

La valeur `50` ne devra donc pas être codée en dur sous prétexte que le périmètre actuel contient uniquement les nitrates.

---

# 3.6 Conformité du prélèvement

| Colonne RAW | Type RAW | Qualité / particularité | Décision STG | ODS potentiel | Intérêt analytique |
|---|---|---|---|---|---|
| `conclusion_conformite_prelevement` | STRING | texte libre, renseigné | conserver tel quel | descriptif / traçabilité | contexte du prélèvement |
| `conformite_limites_bact_prelevement` | STRING | 311 `C` | conserver | normalisation éventuelle | KPI prélèvement |
| `conformite_limites_pc_prelevement` | STRING | 311 `C` | conserver | normalisation éventuelle | KPI prélèvement |
| `conformite_references_bact_prelevement` | STRING | 311 `C` | conserver | normalisation éventuelle | KPI prélèvement |
| `conformite_references_pc_prelevement` | STRING | 286 `C`, 25 `N` | conserver | normalisation éventuelle | KPI prélèvement |

### Décision

Les codes `C` et `N` ne sont pas convertis en booléens dans STG.

La conclusion textuelle ne sera pas parsée pour tenter d'identifier automatiquement le paramètre responsable d'une éventuelle non-conformité.

Les futurs KPI devront distinguer explicitement :

```text
conformité du prélèvement
```

et :

```text
dépassement / conformité du résultat d'un paramètre
```

---

# 3.7 Acteurs et installation amont

| Colonne RAW | Type RAW | Qualité / particularité | Décision STG | ODS / DIM potentiel | Intérêt analytique |
|---|---|---|---|---|---|
| `nom_uge` | STRING | 2 valeurs actuellement | conserver | axe métier à étudier | analyse par UGE éventuelle |
| `nom_distributeur` | STRING | 2 valeurs actuellement | conserver | axe métier à étudier | analyse par distributeur |
| `nom_moa` | STRING | 2 valeurs actuellement | conserver | axe métier à étudier | analyse par MOA |
| `code_installation_amont` | STRING | 4 codes, renseigné | conserver | identifiant candidat d'une dimension installation | analyse par installation |
| `nom_installation_amont` | STRING | libellé pouvant évoluer pour un même code | conserver | attribut descriptif de l'installation | affichage BI |

### Décision

Les rôles :

```text
UGE
distributeur
MOA
```

restent distincts.

Ils ne sont pas regroupés artificiellement dans une unique entité `acteur`.

La création éventuelle de dimensions séparées sera décidée ultérieurement.

Pour les installations :

```text
code_installation_amont
```

est privilégié comme identifiant métier par rapport au libellé.

---

# 3.8 Réseaux

| Colonne RAW | Type RAW | Qualité / particularité | Décision STG | Transformation ODS potentielle | DIM / FACT potentiel |
|---|---|---|---|---|---|
| `reseaux` | ARRAY<STRUCT> | plusieurs éléments par analyse, variantes de noms et débits | conserver l'ARRAY sans `UNNEST` | modèle relation analyse ↔ réseau séparé | bridge + dimension réseau potentielle |

Le champ contient :

```text
ARRAY<STRUCT<
    code STRING,
    nom STRING,
    debit STRING
>>
```

L'exploration a montré :

```text
311 analyses
→ 1 837 éléments après UNNEST
→ 5 codes réseau distincts
```

Après déduplication des codes réseau, une analyse possède actuellement :

```text
1 à 3 réseaux distincts
```

### Décision STG

Le modèle principal :

```text
stg_resultats_dis
```

doit conserver :

```text
reseaux
```

sous sa forme imbriquée.

Il ne doit pas effectuer directement :

```sql
UNNEST(reseaux)
```

car cela modifierait le grain du modèle et dupliquerait les mesures.

---

# 4. Cas particulier de la relation analyse ↔ réseau

La relation avec les réseaux devra être traitée dans un modèle séparé.

Architecture conceptuelle envisagée :

```text
                 stg_resultats_dis
                 grain : résultat
                        │
            ┌───────────┴───────────┐
            │                       │
            ▼                       ▼
    résultats d'analyse      relation analyse-réseau
                                    │
                                    ▼
                              UNNEST(reseaux)
                                    │
                                    ▼
                               code_reseau
```

Le grain du futur modèle relationnel pourrait être :

> Une association entre une analyse / un prélèvement et un code réseau distinct.

Cette hypothèse sera précisée lors de la conception ODS.

---

## 4.1 Déduplication des réseaux

Un même `code_reseau` peut apparaître plusieurs fois avec différents noms.

Exemple observé :

```text
045000474
├── ORLEANS
├── ORLEANS-ST JEAN LE BLANC-ST PRYVÉ
└── ORLEANS-ST JEAN LE BLANC-ST PRYVÉ-ST DENIS EN VAL
```

Le futur modèle relationnel devra donc prévoir une stratégie de déduplication.

Une clé conceptuelle potentielle serait :

```text
identifiant analyse / prélèvement
+
code_reseau
```

Cette règle n'est cependant pas encore implémentée.

---

## 4.2 Débit réseau

Le champ :

```text
reseaux.debit
```

ne constitue pas un attribut fixe du réseau.

Un même réseau peut être associé à plusieurs valeurs de débit.

Par conséquent, une structure telle que :

```text
dim_reseau
├── code_reseau
├── nom_reseau
└── debit_reseau
```

n'est pas retenue à ce stade.

La place du débit devra être déterminée dans le contexte de la relation analyse ↔ réseau.

---

## 4.3 Réseau et installation

Le code :

```text
045000474
```

a été observé à la fois comme :

```text
code_installation_amont
```

et comme :

```text
code_reseau
```

Il s'agit du seul chevauchement observé entre les codes des deux ensembles.

Cela ne signifie pas que :

```text
installation = réseau
```

Les deux concepts restent séparés dans la modélisation.

---

# 5. Synthèse du contrat STG

À l'issue de l'analyse des 32 champs, aucune colonne n'est supprimée dans le premier modèle de staging.

Le contrat envisagé pour :

```text
stg_resultats_dis
```

est donc :

```text
RAW
311 lignes × 32 champs
        │
        ▼
STG
grain préservé
32 champs conservés
```

Les principales règles sont :

```text
✓ conserver les identifiants sous forme STRING

✓ conserver les valeurs NULL lorsqu'elles proviennent
  naturellement de la source

✓ conserver resultat_numerique et resultat_alphanumerique

✓ conserver la limite de qualité sous sa forme source

✓ conserver les informations de conformité du prélèvement
  sans les assimiler à la conformité du paramètre

✓ conserver reseaux sous forme ARRAY<STRUCT>

✓ ne pas UNNEST les réseaux dans le modèle principal

✓ ne pas créer de logique métier complexe dans STG
```

Le staging reste donc volontairement proche de la RAW.

Cette proximité n'est pas une absence de transformation : elle résulte d'un choix visant à préserver le grain et la sémantique de la source avant les transformations métier.

---

# 6. Transformations volontairement reportées à ODS

La matrice a identifié plusieurs transformations potentielles qui ne seront pas réalisées dans STG.

## Résultats censurés

```text
"<0,5"
   ↓
operateur_resultat
seuil_resultat
```

## Limites de qualité

```text
"<=50 mg/L"
      ↓
operateur_limite
limite_qualite_numerique
unite_limite
```

## Temps

```text
date_prelevement
      ↓
année
trimestre
mois
...
```

selon les besoins analytiques.

## Réseaux

```text
ARRAY<STRUCT>
      ↓
UNNEST
      ↓
déduplication
      ↓
relation analyse ↔ réseau
```

## Conformité

Une normalisation des codes de conformité pourra être envisagée après validation de leur sémantique.

---

# 7. Premiers candidats pour le modèle décisionnel

Sans figer encore l'architecture DIM / FACT, la matrice fait apparaître plusieurs candidats.

```text
Dimension géographique
        ↑
code_departement
code_commune
libellés associés

Dimension paramètre
        ↑
code_parametre
libelle_parametre
unité
...

Dimension installation
        ↑
code_installation_amont
nom_installation_amont

Dimension réseau
        ↑
code_reseau
nom_reseau
        │
        │ relation N
        ▼
Bridge analyse ↔ réseau
```

La future table de faits pourrait notamment porter les mesures associées aux résultats :

```text
resultat_numerique
résultat interprété
limite de qualité numérique
écart éventuel à la limite
...
```

Ces structures restent des **candidats** et seront validées lors de la conception ODS puis DIM / FACT.

---

# 8. Intérêt analytique potentiel

La matrice fait émerger plusieurs familles d'analyses potentielles.

## Résultats

```text
concentration moyenne
concentration minimale
concentration maximale
évolution temporelle
```

## Qualité du paramètre

```text
dépassement de limite
écart à la limite
évolution des dépassements
```

## Prélèvements

```text
nombre de prélèvements
conformité aux limites
conformité aux références
évolution temporelle de la conformité
```

## Axes d'analyse

```text
temps
commune
département
paramètre
installation
réseau
UGE
distributeur
MOA
```

Ces éléments constituent des pistes et non encore la liste définitive des KPI du dashboard.

---

# 9. État de la conception

```text
Exploration générale de la RAW       ✅
Analyse du grain                     ✅
Analyse des 32 champs                ✅
Matrice de conception                ✅

Contrat STG                          ✅ défini conceptuellement

Implémentation stg_resultats_dis     ← PROCHAINE ÉTAPE

Tests / documentation dbt           À venir
Conception ODS                       À venir
Conception DIM / FACT                À venir
Définition finale des KPI            À venir
Datavisualisation                    À venir
```

---

# 10. Prochaine étape

La prochaine étape consiste à traduire le contrat de staging en modèle dbt :

```text
dbt/models/staging/stg_resultats_dis.sql
```

Le modèle devra notamment :

1. utiliser la source déclarée dans `sources.yml` ;
2. préserver le grain de la table RAW ;
3. conserver les 32 champs retenus ;
4. conserver les types adaptés ;
5. ne pas éclater `reseaux` ;
6. éviter les transformations métier réservées à ODS.

Une fois le modèle construit, son résultat devra être contrôlé avant de poursuivre vers la couche ODS.
