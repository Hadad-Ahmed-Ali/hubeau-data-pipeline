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


# 12. Exploration de la complétude des données

Une analyse des valeurs `NULL` et des chaînes vides a été réalisée avant la conception des modèles dbt.

La majorité des colonnes étudiées sont entièrement renseignées sur les 311 observations.

Deux champs sont cependant totalement absents sur le périmètre actuel :

```text
reference_qualite_parametre
libelle_parametre_web
```

soit :

```text
311 valeurs absentes sur 311
```

Un autre champ est partiellement renseigné :

```text
code_parametre_cas
```

avec :

```text
139 valeurs absentes sur 311
172 valeurs renseignées
```

soit environ :

```text
44,7 % de valeurs absentes
```

Les autres champs simples contrôlés ne présentent pas de valeurs manquantes sur le périmètre actuel.

Cela concerne notamment :

```text
code_departement
nom_departement
code_commune
nom_commune
code_prelevement
reference_analyse
date_prelevement

code_parametre
code_parametre_se
libelle_parametre
libelle_parametre_maj
code_type_parametre

resultat_numerique
resultat_alphanumerique

code_unite
libelle_unite
limite_qualite_parametre

nom_uge
nom_distributeur
nom_moa

code_installation_amont
nom_installation_amont

code_lieu_analyse
```

Les champs de conformité sont également renseignés sur les 311 observations.

### Conséquence pour le staging

La présence de colonnes entièrement vides sur le périmètre nitrate actuel ne signifie pas automatiquement qu'elles doivent être supprimées.

Le pipeline pourra ultérieurement être étendu à d'autres paramètres Hub'Eau pour lesquels ces informations pourraient être renseignées.

La décision de conservation ou non sera donc prise dans la matrice de conception des colonnes.

---

# 13. Exploration des résultats nitrate

Les résultats du paramètre nitrate sont présents sous deux formes :

```text
resultat_alphanumerique
resultat_numerique
```

L'exploration a montré deux situations.

## 13.1 Résultats numériques classiques

Sur les 311 observations :

```text
265
```

possèdent une représentation numérique classique.

Exemples :

```text
resultat_alphanumerique    resultat_numerique

0,2                        0.2
0,3                        0.3
0,5                        0.5
0,54                       0.54
1,2                        1.2
```

Les résultats numériques observés se situent entre :

```text
0.2 mg/L
```

et :

```text
16.0 mg/L
```

---

## 13.2 Résultats inférieurs à une limite de mesure

Les :

```text
46
```

autres observations possèdent :

```text
resultat_alphanumerique = <0,5
```

alors que :

```text
resultat_numerique = 0.0
```

La valeur :

```text
<0,5
```

ne signifie pas que la concentration réelle est égale à :

```text
0 mg/L
```

mais seulement qu'elle est inférieure à :

```text
0,5 mg/L
```

L'information portée par `resultat_alphanumerique` est donc importante et ne peut pas être remplacée sans précaution par `resultat_numerique`.

### Première règle de modélisation

> Conserver dans le staging les représentations numérique et alphanumérique du résultat afin de ne pas perdre l'information liée aux résultats de type `<0,5`.

Une transformation ultérieure pourra éventuellement dériver :

```text
operateur_resultat = <
seuil_resultat     = 0.5
```

mais cette transformation devra être conçue explicitement plutôt que déduite naïvement de `resultat_numerique = 0`.

---

# 14. Exploration de la limite de qualité

La limite de qualité est stockée dans :

```text
limite_qualite_parametre
```

sous forme de chaîne de caractères.

Sur l'ensemble des 311 observations :

```text
limite_qualite_parametre = <=50 mg/L
code_unite               = 162
libelle_unite            = mg/L
```

La limite est donc parfaitement homogène sur le périmètre nitrate actuel.

Une future transformation pourra éventuellement séparer :

```text
<=50 mg/L
```

en :

```text
operateur_limite         = <=
limite_qualite_numerique = 50
unite                    = mg/L
```

Cependant, cette transformation ne devra pas être codée spécifiquement pour les nitrates.

Elle devra rester générique afin de pouvoir fonctionner si d'autres paramètres Hub'Eau sont intégrés au pipeline.

---

# 15. Résultats nitrate et limite de qualité

Sur les données actuellement observées :

```text
résultat nitrate maximum = 16 mg/L
limite de qualité        = 50 mg/L
```

Aucun résultat nitrate du périmètre actuel ne dépasse donc la limite indiquée dans :

```text
limite_qualite_parametre
```

Cette information pourra être utile pour les futurs indicateurs de qualité.

Il faudra cependant distinguer clairement :

```text
conformité du résultat nitrate
```

et :

```text
conformité globale du prélèvement
```

car ces deux notions ne sont pas équivalentes dans la source Hub'Eau.

---

# 16. Exploration de la conformité du prélèvement

Les champs suivants ont été étudiés :

```text
conformite_limites_bact_prelevement
conformite_limites_pc_prelevement
conformite_references_bact_prelevement
conformite_references_pc_prelevement
```

Les distributions observées sont :

| Indicateur | Valeur | Nombre |
|---|---|---:|
| Limites bactériologiques | C | 311 |
| Limites physico-chimiques | C | 311 |
| Références bactériologiques | C | 311 |
| Références physico-chimiques | C | 286 |
| Références physico-chimiques | N | 25 |

Ainsi :

```text
conformite_limites_bact_prelevement
conformite_limites_pc_prelevement
conformite_references_bact_prelevement
```

sont systématiquement égaux à :

```text
C
```

sur le périmètre actuel.

Seul :

```text
conformite_references_pc_prelevement
```

varie :

```text
C → 286 observations
N → 25 observations
```

soit approximativement :

```text
91,96 % C
8,04 % N
```

---

# 17. Conformité globale ≠ conformité nitrate

L'exploration de :

```text
conclusion_conformite_prelevement
```

montre que cette colonne porte une conclusion concernant **l'ensemble des paramètres mesurés lors du prélèvement**.

Les textes observés mentionnent notamment :

```text
pesticides
PFAS
fer
manganèse
perchlorates
turbidité
carbone organique total
température
agressivité de l'eau
```

alors que notre extraction ne contient actuellement que le paramètre :

```text
Nitrates
```

Il serait donc incorrect de considérer :

```text
conclusion_conformite_prelevement
```

comme une mesure directe de la conformité du résultat nitrate.

Par exemple :

```text
une ligne nitrate
        │
        ▼
conclusion du prélèvement
        │
        ├── peut concerner le nitrate
        └── peut concerner un autre paramètre
```

### Règle de modélisation

> Les champs de conformité du prélèvement doivent être conservés avec une sémantique clairement distincte de la conformité propre au paramètre nitrate.

Un futur KPI du type :

```text
taux de résultats nitrate conformes
```

ne devra donc pas être calculé directement à partir de :

```text
conclusion_conformite_prelevement
```

Le texte libre pourra être conservé pour information et traçabilité, mais il ne constituera pas la base principale de la logique analytique.

---

# 18. Exploration des acteurs et des installations

Les cardinalités observées sont :

```text
UGE                  : 2
Distributeurs        : 2
MOA                  : 2
Installations amont  : 4
```

Une analyse temporelle a mis en évidence deux périodes principales.

## 18.1 Période 2016–2020

Les observations utilisent :

```text
UGE          : AEP ORLEANS
Distributeur : L'ORLEANAISE DES EAUX
MOA          : MAIRIE D'ORLEANS
```

Les principales installations observées sont :

```text
045000762 → USINE DU VAL ORLEANS
045000729 → DEFERRISATION CLOS DES BOEUFS
045003593 → DEFERRISATION LA SOURCE
```

---

## 18.2 Période à partir de 2021

Les observations utilisent :

```text
UGE          : METROPOLE SUEZ AQUALIGE
Distributeur : SUEZ AQUALIGE
MOA          : ORLEANS METROPOLE
```

Certaines installations conservent le même identifiant malgré les changements d'acteurs.

Par exemple :

```text
045000762
```

est présent avant et après 2021.

Son libellé évolue cependant de :

```text
USINE DU VAL ORLEANS
```

vers :

```text
USINE DE TRAITEMENT DU VAL ORLEANS
```

Les codes :

```text
045003593
045000729
```

sont également présents dans les deux périodes.

### Première conclusion

Comme pour les réseaux :

> `code_installation_amont` apparaît plus stable que `nom_installation_amont` pour identifier une installation.

La modélisation devra donc privilégier le code comme identifiant métier de l'installation.

---

# 19. Cas particulier de l'installation `045000474`

Une quatrième installation apparaît en 2026 :

```text
code_installation_amont = 045000474
```

avec :

```text
nom_installation_amont =
ORLEANS-ST JEAN LE BLANC-ST PRYVÉ-ST DENIS EN VAL
```

Ce code existe également parmi les :

```text
code_reseau
```

Une vérification du chevauchement entre les codes d'installation et les codes réseau a montré qu'il s'agit du seul code présent dans les deux ensembles :

```text
code_installation_amont    code_reseau
045000474                  045000474
```

Cette observation ne permet pas de conclure que :

```text
installation = réseau
```

Les deux concepts doivent rester distincts dans la modélisation.

Le sens du code dépend de son contexte :

```text
code_installation_amont
```

et :

```text
code_reseau
```

représentent des rôles différents dans les données.

---

# 20. Synthèse des cardinalités observées

À la fin de cette phase d'exploration, le périmètre actuel présente :

```text
311 analyses
     │
     ├── 311 prélèvements distincts
     ├── 311 références d'analyse distinctes
     │
     ├── 1 département
     ├── 1 commune
     │
     ├── 1 paramètre
     ├── 1 unité
     ├── 1 lieu d'analyse
     │
     ├── 2 UGE
     ├── 2 distributeurs
     ├── 2 MOA
     │
     ├── 4 installations amont
     │
     └── 5 codes réseau
```

Cette structure est liée au périmètre actuellement limité à :

```text
Orléans + Nitrates
```

La modélisation devra cependant rester suffisamment générique pour supporter une extension future du pipeline.

---

# 21. Points établis à l'issue de l'exploration

Les conclusions suivantes peuvent désormais être retenues pour le jeu de données actuel.

## Grain

1. La table RAW contient 311 lignes et 32 champs.

2. Les 311 lignes possèdent 311 `code_prelevement` distincts.

3. Les 311 lignes possèdent 311 `reference_analyse` distinctes.

4. Le grain observé est actuellement celui d'un résultat nitrate associé à un prélèvement.

5. Ce grain devra être revérifié si plusieurs paramètres sont intégrés ultérieurement.

## Résultats

6. 265 résultats sont des valeurs numériques classiques.

7. 46 résultats sont exprimés sous la forme `<0,5`.

8. `resultat_numerique = 0` ne doit pas être interprété comme une concentration réellement égale à zéro pour ces 46 observations.

9. Les représentations numérique et alphanumérique doivent donc être conservées au moins dans le staging.

## Qualité

10. La limite de qualité est actuellement toujours `<=50 mg/L`.

11. Le résultat nitrate maximal observé est `16 mg/L`.

12. Aucun résultat nitrate observé ne dépasse actuellement cette limite.

13. `reference_qualite_parametre` est entièrement vide sur le périmètre actuel.

## Conformité

14. Les conformités de limites bactériologiques et physico-chimiques sont toutes égales à `C`.

15. La conformité aux références bactériologiques est également toujours `C`.

16. La conformité aux références physico-chimiques contient 286 `C` et 25 `N`.

17. La conclusion du prélèvement concerne potentiellement plusieurs paramètres et ne doit pas être assimilée à une conclusion nitrate.

## Réseaux

18. Toutes les analyses possèdent plusieurs éléments dans `reseaux`.

19. `UNNEST(reseaux)` produit 1 837 éléments à partir de 311 analyses.

20. Ces éléments représentent seulement 5 codes réseau distincts.

21. Une analyse est associée à 1, 2 ou 3 codes réseau distincts.

22. Un même `code_reseau` peut posséder plusieurs variantes de nom.

23. `code_reseau` est plus stable que `nom_reseau`.

24. `debit_reseau` n'est pas un attribut fixe du réseau.

25. Les réseaux ne doivent pas être intégrés naïvement au grain principal des résultats.

## Acteurs et installations

26. Deux groupes d'UGE / distributeur / MOA apparaissent dans les données, avec une rupture temporelle observée autour de 2021.

27. Certaines installations conservent le même code malgré un changement de libellé ou d'acteurs.

28. `code_installation_amont` apparaît plus stable que son libellé.

29. Installation et réseau doivent rester deux concepts distincts.

## Complétude

30. `libelle_parametre_web` est entièrement vide.

31. `reference_qualite_parametre` est entièrement vide.

32. `code_parametre_cas` est absent dans 139 observations.

---

# 22. Règles de conception déjà identifiées

Avant même la construction des modèles, plusieurs règles peuvent être retenues :

```text
1. Préserver le grain principal des résultats d'analyse.

2. Ne pas UNNEST(reseaux) directement dans le modèle principal
   si cela duplique les mesures.

3. Privilégier les codes métier aux libellés lorsque les codes
   apparaissent plus stables.

4. Conserver la représentation alphanumérique du résultat.

5. Ne pas considérer resultat_numerique = 0 comme une vraie
   concentration nulle lorsque resultat_alphanumerique = "<0,5".

6. Ne pas assimiler la conformité globale du prélèvement
   à la conformité du nitrate.

7. Ne pas considérer debit_reseau comme un attribut fixe
   d'un réseau.

8. Garder installations et réseaux comme concepts distincts.

9. Éviter de supprimer automatiquement les colonnes vides
   avant de considérer l'extension future du périmètre.

10. Concevoir les transformations à partir des futurs besoins
    analytiques et KPI plutôt que simplement reproduire la RAW.
```

---

# 23. Fin de l'exploration générale

À ce stade, l'exploration générale de la table RAW est considérée comme suffisamment avancée pour commencer la conception des transformations dbt.

Les principaux éléments étudiés sont :

```text
Grain                               ✅
Cardinalités                        ✅
NULL / valeurs vides                ✅
Résultats numériques                ✅
Résultats alphanumériques           ✅
Limite de qualité                   ✅
Conformité                          ✅
Acteurs                             ✅
Installations                       ✅
Réseaux                             ✅
Relations analyse-réseau            ✅
Évolution temporelle des acteurs    ✅
```

Les prochaines requêtes exploratoires seront désormais réalisées uniquement lorsqu'une question précise de modélisation le nécessitera.

---

# 24. Prochaine étape — Matrice de conception des 32 champs

La prochaine étape consiste à analyser chaque colonne de la RAW selon plusieurs dimensions :

| Élément étudié | Objectif |
|---|---|
| Signification | Comprendre le rôle du champ |
| Type source | Vérifier le type BigQuery |
| Cardinalité | Comprendre la diversité des valeurs |
| Complétude | Identifier NULL / valeurs vides |
| Stabilité | Identifier les codes et libellés fiables |
| Traitement STG | Renommer / nettoyer / conserver |
| Traitement ODS | Restructurer / dériver |
| DIM / FACT | Déterminer le rôle décisionnel potentiel |
| KPI | Identifier l'intérêt analytique |

La matrice suivra donc la logique :

```text
32 colonnes RAW
        │
        ▼
┌──────────────────────────────────────┐
│ Signification                        │
│ Type                                 │
│ Cardinalité                          │
│ Qualité                              │
│ Traitement STG                       │
│ Traitement ODS                       │
│ Utilisation DIM / FACT               │
│ Intérêt KPI                          │
└──────────────────────────────────────┘
        │
        ▼
Contrat de transformation STG
        │
        ▼
stg_resultats_dis
```

Cette étape permettra de décider précisément :

- quelles colonnes conserver ;
- lesquelles renommer ;
- lesquelles normaliser ;
- lesquelles conserver uniquement pour traçabilité ;
- quelles transformations reporter à la couche ODS ;
- quelles entités pourront devenir des dimensions ;
- quelles informations devront alimenter les futures tables de faits.

---

## État de l'exploration

```text
Compréhension générale de la RAW       ✅
Analyse du grain                       ✅
Analyse des cardinalités               ✅
Analyse de reseaux                     ✅
Profil NULL / valeurs vides            ✅
Analyse des résultats                  ✅
Analyse de la limite de qualité        ✅
Analyse de la conformité               ✅
Analyse acteurs / installations        ✅

Exploration générale                   ✅ TERMINÉE

Matrice des 32 champs                  ← PROCHAINE ÉTAPE

Conception STG                         À venir
Conception ODS                         À venir
Conception DIM / FACT                  À venir
Définition des KPI                     À venir
Datavisualisation                      À venir
```
