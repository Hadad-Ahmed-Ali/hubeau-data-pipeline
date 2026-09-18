# Page 3 : Analyse des paramètres

## 1. Objectif de la page

Cette page répond à la question métier :

> **Comment évoluent les valeurs mesurées des différents paramètres dans le temps, en tenant compte de la nature directe ou censurée des résultats ?**

L'objectif est de permettre à l'utilisateur :

- d'analyser un paramètre de qualité de l'eau à la fois ;
- d'identifier la nature des résultats disponibles ;
- de distinguer les valeurs directes, les résultats censurés et les résultats non exploitables numériquement ;
- de calculer des statistiques descriptives uniquement sur les valeurs directement quantifiées ;
- d'analyser l'évolution temporelle du paramètre ;
- de visualiser parallèlement la présence de résultats censurés dans le temps ;
- de contextualiser les mesures par rapport à une règle de qualité lorsqu'une règle unique et non ambiguë peut être affichée.

Cette page constitue le troisième niveau de lecture du dashboard.

Après la vision globale de la conformité des prélèvements présentée en **Page 1** et l'analyse des dépassements de règles de qualité présentée en **Page 2**, elle permet d'étudier plus précisément le comportement des mesures d'un paramètre.

---

## 2. Source et grain analytique

### Source principale

La source principale de cette page est :

`fact_resultats`

### Grain

**1 ligne = 1 résultat d'un paramètre donné, pour un prélèvement donné et un lieu d'analyse donné.**

La clé métier utilisée sur le périmètre actuel est constituée de :

`code_prelevement + code_parametre + code_lieu_analyse`

La Page 3 travaille donc au même grain résultat que la Page 2.

Cependant, son objectif est différent :

```text
Page 2
→ classification des résultats par rapport aux règles de qualité

Page 3
→ analyse descriptive et temporelle des mesures
```

---

## 3. Principe analytique principal

La principale difficulté de cette page concerne la nature des résultats.

Tous les résultats présents dans `fact_resultats` ne peuvent pas être interprétés comme des valeurs numériques directement mesurées.

Trois catégories sont distinguées :

```text
RÉSULTATS
   │
   ├── Valeurs directes
   │      → valeurs directement quantifiées
   │      → utilisables pour les statistiques descriptives
   │
   ├── Résultats censurés "<x"
   │      → information numérique partielle
   │      → conservés dans l'analyse
   │      → non assimilés à une valeur exacte
   │
   └── N.M.
          → absence de valeur numérique exploitable
          → conservés dans les comptages
          → exclus des statistiques numériques
```

Cette distinction est indispensable pour éviter d'interpréter artificiellement une valeur censurée comme une mesure exacte.

Par exemple :

`<0,05`

ne signifie pas :

`0`

La valeur réelle n'est pas connue précisément ; seule l'information portée par le résultat censuré doit être conservée.

Les choix méthodologiques ayant conduit à cette distinction sont détaillés dans [`reflexion_KPIs.md`](../reflexion_KPIs.md).

---

## 4. Organisation de la page

La page est organisée selon quatre niveaux de lecture :

```text
1. Filtres et paramètre sélectionné
        │
        ▼
2. Nature des résultats
        │
        ▼
3. Statistiques sur les valeurs directes
        │
        ▼
4. Évolution temporelle
```

Le parcours analytique attendu est :

```text
Quel paramètre est étudié ?
        │
        ▼
Quelle est la nature des résultats disponibles ?
        │
        ▼
Que montrent les valeurs directement quantifiées ?
        │
        ▼
Comment évoluent-elles dans le temps ?
```

---

## 5. Filtres

Les filtres principaux de la Page 3 sont :

```text
Période
Paramètre
Installation
Réseau
Lieu d'analyse
```

---

### 5.1 Paramètre

Le filtre **Paramètre** constitue le filtre central de la Page 3.

Il s'appuie sur :

`dim_parametre`

La page analyse **un seul paramètre à la fois**.

Le filtre est donc configuré en :

**sélection unique obligatoire**

Cette règle permet d'éviter de mélanger dans une même analyse des paramètres présentant :

- des unités différentes ;
- des échelles différentes ;
- des significations différentes.

Par exemple, des résultats exprimés en :

```text
mg/L
µg/L
°C
NFU
unité pH
n/(100mL)
```

ne doivent pas être agrégés dans une même moyenne, médiane ou série temporelle.

Le paramètre sélectionné détermine donc :

- l'unité affichée ;
- les populations de résultats ;
- les statistiques descriptives ;
- l'évolution temporelle ;
- les éventuelles informations relatives à la règle de qualité.

---

### 5.2 Période

Le filtre **Période** s'appuie sur :

`dim_date`

Il permet de restreindre toutes les observations du paramètre sélectionné à une période donnée.

Il agit sur :

- le nombre total de résultats ;
- le nombre de valeurs directes ;
- le nombre de résultats censurés ;
- le nombre de résultats `N.M.` ;
- les statistiques descriptives ;
- les graphiques temporels.

---

### 5.3 Installation

Le filtre **Installation** s'appuie sur :

`dim_installation`

Il permet d'analyser le comportement du paramètre pour une installation amont particulière.

---

### 5.4 Réseau

Le filtre **Réseau** repose sur l'association entre les prélèvements et les réseaux portée par :

`bridge_prelevements_reseaux`

Le réseau n'est pas directement porté par `fact_resultats`.

Le principe fonctionnel est donc :

> **Sélectionner un réseau doit conserver les résultats appartenant aux prélèvements associés au réseau sélectionné, sans dupliquer les résultats lorsqu'un prélèvement est associé à plusieurs réseaux.**

La relation conceptuelle est :

```text
dim_reseau
     │
     ▼
bridge_prelevements_reseaux
     │
     │ code_prelevement
     ▼
Prélèvements associés
     │
     ▼
fact_resultats
```

L'implémentation Power BI devra préserver le grain de `fact_resultats`.

---

### 5.5 Lieu d'analyse

Le filtre **Lieu d'analyse** repose sur :

`code_lieu_analyse`

Il permet de distinguer les résultats selon leur lieu d'analyse.

Ce filtre est compatible avec la Page 3 puisque le lieu d'analyse appartient directement au grain de `fact_resultats`.

---

## 6. Identification du paramètre et de son unité

La partie supérieure de la page rappelle explicitement le paramètre actuellement étudié.

Exemple fonctionnel :

```text
Paramètre sélectionné : X
Unité : X
```

L'unité est une information contextuelle et ne constitue pas un filtre.

Elle doit également accompagner les statistiques descriptives et les axes numériques lorsque cela est pertinent.

---

## 7. Nombre total de résultats

Un indicateur de contexte présente :

```text
X résultats
```

Il représente l'ensemble des résultats correspondant :

- au paramètre sélectionné ;
- à la période sélectionnée ;
- aux autres filtres actifs.

Ce total inclut :

```text
Valeurs directes
+
Résultats censurés
+
N.M.
```

Il permet de conserver une vision du volume total d'observations avant d'interpréter les statistiques numériques.

---

## 8. Nature des résultats

Trois indicateurs présentent la composition des résultats :

```text
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ VALEURS DIRECTES │ │    CENSURÉS      │ │      N.M.        │
│                  │ │                  │ │                  │
│        X         │ │        X         │ │        X         │
│                  │ │       X %        │ │                  │
└──────────────────┘ └──────────────────┘ └──────────────────┘
```

Ces indicateurs permettent de déterminer immédiatement quelle proportion des observations est directement quantifiée.

Cette information est essentielle avant d'interpréter les statistiques descriptives.

---

## 9. Taux de résultats censurés

Le taux de résultats censurés est calculé uniquement parmi les résultats fournissant une information numérique exploitable.

La formule retenue est :

**Taux de résultats censurés = Nombre de résultats censurés / (Nombre de valeurs directes + Nombre de résultats censurés)**

Les résultats `N.M.` sont :

- conservés dans le nombre total de résultats ;
- affichés séparément ;
- exclus du dénominateur du taux de résultats censurés.

Le KPI répond ainsi à la question :

> **Parmi les résultats fournissant une information numérique, quelle proportion est censurée plutôt que directement quantifiée ?**

---

### 9.1 Cas où le taux n'est pas calculable

Si la sélection contient uniquement des résultats `N.M.`, alors :

```text
Valeurs directes = 0
Résultats censurés = 0
N.M. = X
```

Le dénominateur du taux est nul.

Le dashboard ne doit donc pas afficher :

`0 %`

Il doit afficher :

`—`

ou :

`Non calculable`

Cette distinction est importante :

```text
0 % de résultats censurés
        ≠
impossibilité de calculer le taux
```

Un taux de `0 %` signifie qu'il existe des résultats numériquement exploitables et qu'aucun n'est censuré.

Un taux non calculable signifie qu'aucun résultat ne permet de constituer le dénominateur.

---

## 10. Statistiques descriptives

Les statistiques descriptives sont calculées **uniquement sur les valeurs directes**.

Les trois indicateurs retenus sont :

```text
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│     MÉDIANE      │ │     MOYENNE      │ │     MAXIMUM      │
│                  │ │                  │ │                  │
│    X [unité]     │ │    X [unité]     │ │    X [unité]     │
└──────────────────┘ └──────────────────┘ └──────────────────┘
```

Les résultats censurés et les résultats `N.M.` sont exclus de ces calculs.

Les intitulés doivent préciser la population utilisée, par exemple :

```text
Médiane des valeurs directes
Moyenne des valeurs directes
Maximum des valeurs directes
```

et non simplement :

```text
Médiane
Moyenne
Maximum
```

Cette précision évite de laisser penser que les statistiques représentent l'ensemble des résultats.

---

## 11. Pourquoi le minimum n'est pas retenu

Le minimum des valeurs directes n'est volontairement pas retenu comme KPI.

Cette décision est liée à la présence de résultats censurés.

Exemple :

```text
<0,05
<0,05
<0,05
0,08
0,12
0,20
```

Le minimum des valeurs directes serait :

`0,08`

Cette valeur serait mathématiquement correcte pour les seules valeurs directes.

Cependant, elle pourrait être interprétée comme la plus petite valeur observée dans l'ensemble des résultats, alors que plusieurs observations sont connues comme étant inférieures à `0,05`.

Le minimum des valeurs directes risquerait donc d'être ambigu.

Pour cette raison, la synthèse descriptive conserve :

- la médiane ;
- la moyenne ;
- le maximum ;

mais pas le minimum.

---

## 12. Représentativité des statistiques descriptives

Les statistiques descriptives ne doivent pas être interprétées indépendamment de la nature des résultats.

La page doit toujours permettre de voir simultanément :

```text
Nombre de valeurs directes
Nombre de résultats censurés
Taux de résultats censurés
Nombre de N.M.
```

Cette information permet d'évaluer la représentativité des statistiques calculées sur les valeurs directes.

Par exemple, une moyenne calculée à partir d'une grande majorité des observations n'a pas la même portée qu'une moyenne calculée à partir d'une très faible proportion de valeurs directement quantifiées.

Le dashboard ne cherche pas à corriger cette situation par une imputation arbitraire des valeurs censurées.

Il la rend explicitement visible à l'utilisateur.

---

## 13. Absence de valeur directe

Une sélection peut contenir des résultats sans contenir aucune valeur directement quantifiée.

Par exemple :

```text
<0,05
<0,05
<0,05
```

Dans cette situation :

```text
Nombre total de résultats = X
Valeurs directes = 0
Résultats censurés = X
```

Les statistiques descriptives ne doivent pas afficher :

```text
Médiane = 0
Moyenne = 0
Maximum = 0
```

Elles doivent afficher :

```text
Médiane : —
Moyenne : —
Maximum : —
```

avec un message fonctionnel explicite :

> **Aucune valeur directe disponible pour la sélection actuelle.**

Il ne faut pas afficher :

> Aucune donnée disponible.

Des données sont effectivement présentes ; elles ne sont simplement pas disponibles sous forme de valeurs directes utilisables pour ces statistiques.

---

## 14. Évolution temporelle des valeurs directes

### 14.1 Objectif

Le graphique principal répond à la question :

> **Comment évoluent les valeurs directement quantifiées du paramètre dans le temps ?**

Les résultats censurés ne doivent pas être transformés artificiellement en valeurs numériques exactes pour ce graphique.

---

### 14.2 Agrégation temporelle retenue

Plusieurs résultats directs peuvent exister pour une même période.

Le dashboard ne doit donc pas laisser Power BI appliquer une agrégation implicite telle que :

```text
Somme
```

ou une moyenne choisie automatiquement.

L'indicateur temporel retenu est :

> **Médiane des valeurs directes par période**

Pour chaque période :

**Médiane temporelle = médiane des valeurs directes du paramètre sélectionné sur la période considérée**

Les résultats censurés et `N.M.` sont exclus du calcul.

---

### 14.3 Granularité temporelle

Le niveau affiché par défaut est :

`Année`

L'utilisateur peut ensuite descendre jusqu'au :

`Mois`

La navigation suit donc :

```text
Année
  │
  ▼
Mois
```

Cette approche permet de conserver une tendance générale lisible tout en permettant une analyse plus fine lorsque nécessaire.

---

### 14.4 Visualisation retenue

La visualisation principale est une courbe représentant :

```text
ÉVOLUTION DES VALEURS DIRECTES

Valeur [unité]
 │
 │                 ●
 │        ●───────╯ ╲
 │    ●──╯           ●
 │ ●─╯                 ╲──●
 │
 └────────────────────────────► Temps

       Médiane des valeurs directes
```

Chaque point représente donc une **médiane de valeurs directes**, et non une observation individuelle.

---

### 14.5 Infobulle

L'infobulle du graphique temporel doit permettre de contextualiser chaque point.

Elle présente au minimum :

```text
Période : X
Médiane des valeurs directes : X [unité]
Valeurs directes : X
Résultats censurés : X
N.M. : X
```

Le nombre de valeurs directes est particulièrement important afin de connaître le volume d'observations ayant servi au calcul de la médiane.

---

## 15. Évolution des résultats censurés

Les résultats censurés ne sont pas représentés comme des valeurs exactes dans la courbe principale.

Ils disposent d'un visuel complémentaire montrant leur nombre par période.

Exemple fonctionnel :

```text
RÉSULTATS CENSURÉS

2019  ██
2020  █████
2021  ████████
2022  ███
...
```

Ce graphique permet de répondre à la question :

> **À quelles périodes les résultats censurés sont-ils particulièrement présents ?**

Il évite de transformer artificiellement les expressions `<x` en mesures exactes.

Le taux global de résultats censurés étant déjà disponible dans la zone de synthèse, ce graphique temporel privilégie le **nombre de résultats censurés par période**.

---

## 16. Affichage d'une règle de qualité

Une règle de qualité peut être utilisée comme contexte visuel sur le graphique temporel uniquement lorsqu'elle peut être représentée sans ambiguïté.

### Cas 1 : Règle unique et stable

Si une seule règle applicable existe dans le contexte filtré, un seuil peut être affiché sur le graphique lorsque sa représentation est compatible avec le type de règle.

Exemple conceptuel :

```text
Valeur
 │
 ├──────────────────────── seuil
 │
 │          ●
 │    ●           ●
 │ ●       ●
 │
 └────────────────────────► Temps
```

---

### Cas 2 : Plusieurs seuils applicables

Si plusieurs seuils différents sont applicables aux observations de la sélection, le dashboard ne doit pas tracer artificiellement une ligne unique.

Il peut afficher une information telle que :

> **Plusieurs seuils de qualité sont applicables dans la sélection actuelle.**

Cette règle évite de présenter un seuil unique qui ne correspondrait pas à toutes les observations.

---

### Cas 3 : Aucune règle disponible

Lorsqu'aucune règle de qualité n'est disponible pour le paramètre dans la sélection, aucune ligne de seuil n'est affichée.

Cette absence ne doit pas être interprétée comme une absence de contrainte réglementaire générale.

Elle signifie uniquement qu'aucune règle exploitable pour cet affichage n'est disponible dans les données utilisées par le dashboard pour la sélection actuelle.

---

## 17. Distinction entre classification et analyse statistique

La Page 3 ne doit pas reproduire la logique analytique de la Page 2.

Les deux pages répondent à des questions différentes :

```text
PAGE 2
Classification par rapport aux règles
        │
        ▼
Le résultat respecte-t-il
ou dépasse-t-il la règle ?

PAGE 3
Analyse des mesures
        │
        ▼
Comment les valeurs directement
quantifiées évoluent-elles ?
```

Cette distinction est particulièrement importante pour les résultats censurés.

Une valeur censurée peut parfois fournir suffisamment d'information pour déterminer sa position par rapport à une règle de qualité.

Cela ne signifie pas pour autant qu'elle constitue une valeur exacte pouvant être utilisée dans une moyenne ou une médiane.

Ainsi :

```text
Utilisable pour certaines classifications
                ≠
Valeur exacte utilisable
pour les statistiques descriptives
```

---

## 18. Comportement attendu des filtres

Les filtres doivent respecter le grain résultat.

Le comportement attendu est :

```text
Paramètre
   ↓
sélection unique
   ↓
détermine l'unité et l'analyse principale

Période
   ↓
restreint les observations dans le temps

Installation
   ↓
restreint les résultats associés à l'installation

Lieu d'analyse
   ↓
filtre directement code_lieu_analyse

Réseau
   ↓
identifie les prélèvements associés au réseau
   ↓
conserve leurs résultats
   ↓
sans duplication
```

Toutes les cartes et visualisations doivent être recalculées selon le contexte de filtre actif.

---

## 19. Maquette fonctionnelle simplifiée

```text
┌────────────────────────────────────────────────────────────────────┐
│ PAGE 3 — ANALYSE DES PARAMÈTRES                                   │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│ Période │ Paramètre │ Installation │ Réseau │ Lieu d'analyse      │
│             ↑ sélection unique obligatoire                         │
│                                                                    │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│ Paramètre sélectionné : X                         Unité : X         │
│                                                                    │
│                         X résultats                                │
│                                                                    │
│ ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐     │
│ │ VALEURS DIRECTES │ │    CENSURÉS      │ │      N.M.        │     │
│ │        X         │ │        X         │ │        X         │     │
│ │                  │ │       X %        │ │                  │     │
│ └──────────────────┘ └──────────────────┘ └──────────────────┘     │
│                                                                    │
├────────────────────────────────────────────────────────────────────┤
│            STATISTIQUES — VALEURS DIRECTES UNIQUEMENT             │
│                                                                    │
│ ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐     │
│ │     MÉDIANE      │ │     MOYENNE      │ │     MAXIMUM      │     │
│ │    X [unité]     │ │    X [unité]     │ │    X [unité]     │     │
│ └──────────────────┘ └──────────────────┘ └──────────────────┘     │
│                                                                    │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│              ÉVOLUTION DES VALEURS DIRECTES                       │
│                                                                    │
│        Courbe → médiane des valeurs directes par période          │
│                                                                    │
│        Année par défaut → navigation jusqu'au mois                │
│                                                                    │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│              ÉVOLUTION DES RÉSULTATS CENSURÉS                     │
│                                                                    │
│        Colonnes → nombre de résultats censurés par période        │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## 20. Cas particuliers à préserver

La Page 3 doit explicitement gérer les situations suivantes :

### Résultats censurés

```text
<x
```

Ils sont conservés mais ne sont jamais assimilés automatiquement à une valeur exacte égale à zéro.

### Résultats N.M.

Ils sont conservés dans les volumes mais exclus des statistiques numériques.

### Aucun résultat numériquement exploitable

Le taux de résultats censurés est :

`Non calculable`

et non :

`0 %`

### Aucune valeur directe

Les statistiques descriptives affichent :

`—`

avec :

> **Aucune valeur directe disponible pour la sélection actuelle.**

### Plusieurs résultats directs dans une période

Ils sont agrégés explicitement par :

**médiane des valeurs directes**

et jamais par une somme ou une agrégation implicite de Power BI.

### Plusieurs règles de qualité

Aucune ligne de seuil unique n'est affichée si plusieurs règles différentes sont applicables.

### Filtrage par réseau

Le filtrage ne doit pas provoquer de duplication des résultats.

---

## 21. Résultat attendu

La Page 3 doit permettre à l'utilisateur de comprendre la structure et l'évolution des mesures d'un paramètre sans introduire d'hypothèses artificielles sur les résultats censurés.

Elle doit permettre de répondre successivement à :

```text
Quel paramètre est analysé ?
        │
        ▼
Combien de résultats sont disponibles ?
        │
        ▼
Quelle proportion est directement quantifiée,
censurée ou non exploitable ?
        │
        ▼
Que montrent les valeurs directes ?
        │
        ▼
Comment leur médiane évolue-t-elle dans le temps ?
        │
        ▼
Quand les résultats censurés sont-ils observés ?
```

La page doit conserver les principes analytiques suivants :

- analyser un seul paramètre à la fois ;
- ne jamais mélanger des paramètres présentant des unités différentes ;
- distinguer les valeurs directes, censurées et `N.M.` ;
- ne jamais interpréter automatiquement `<x` comme une valeur exacte égale à zéro ;
- exclure les résultats censurés des statistiques descriptives sur les valeurs directes ;
- exclure les `N.M.` des calculs numériques ;
- afficher la proportion de résultats censurés afin de contextualiser les statistiques ;
- ne pas afficher de faux `0` lorsqu'un indicateur n'est pas calculable ;
- utiliser la médiane des valeurs directes pour l'évolution temporelle ;
- ne jamais utiliser une somme des mesures ;
- ne pas laisser Power BI choisir implicitement l'agrégation temporelle ;
- ne représenter un seuil de qualité que lorsqu'il peut être affiché sans ambiguïté ;
- préserver le grain des résultats lors du filtrage par réseau.

La Page 3 constitue ainsi le niveau d'**analyse descriptive des paramètres** du dashboard.

Elle complète :

```text
PAGE 1
Conformité des prélèvements
        │
        ▼
PAGE 2
Dépassements des règles de qualité
        │
        ▼
PAGE 3
Analyse des paramètres
```

Ces trois pages constituent ensemble le parcours analytique principal du dashboard Hub'Eau.
