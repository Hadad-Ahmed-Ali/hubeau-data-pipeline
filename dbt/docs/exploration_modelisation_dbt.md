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
