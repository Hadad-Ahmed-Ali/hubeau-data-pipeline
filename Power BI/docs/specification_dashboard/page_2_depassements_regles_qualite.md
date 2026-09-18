# Page 2 : Dépassements des règles de qualité

## 1. Objectif de la page

Cette page répond à la question métier :

> **Quels paramètres présentent des dépassements de limites ou de références de qualité, à quelle fréquence et à quelles périodes ?**

L'objectif est de permettre à l'utilisateur :

- d'identifier l'existence de dépassements de règles de qualité ;
- de distinguer les **limites de qualité** des **références de qualité** ;
- d'identifier les paramètres concernés ;
- de comparer la fréquence des dépassements entre paramètres ;
- d'analyser leur évolution dans le temps ;
- d'explorer les résultats selon la période, le paramètre, l'installation, le réseau et le lieu d'analyse.

Cette page constitue le deuxième niveau de lecture du dashboard.

Après la vision globale de la conformité des prélèvements présentée en **Page 1**, elle permet de descendre au niveau des résultats d'analyse afin d'identifier les paramètres associés aux dépassements observés.

---

## 2. Source et grain analytique

### Source principale

La source principale de cette page est :

`fact_resultats`

### Grain

**1 ligne = 1 résultat d'un paramètre donné, pour un prélèvement donné et un lieu d'analyse donné.**

La clé métier utilisée sur le périmètre actuel est constituée de :

`code_prelevement + code_parametre + code_lieu_analyse`

Ce grain permet d'analyser séparément les résultats des différents paramètres sans confondre :

- le prélèvement ;
- le paramètre analysé ;
- le lieu d'analyse.

La Page 2 travaille donc au **grain résultat**, contrairement à la Page 1 qui travaille au grain prélèvement.

---

## 3. Principe analytique principal

Les **limites de qualité** et les **références de qualité** correspondent à deux notions distinctes.

Elles doivent donc être analysées séparément dans le dashboard.

La page ne doit pas construire un indicateur global additionnant :

- les dépassements de limites de qualité ;
- les dépassements de références de qualité.

Un indicateur tel que :

`Total des non-conformités`

n'est volontairement pas retenu.

La structure analytique de la page repose sur :

```text
RÈGLES DE QUALITÉ
        │
        ├── Limites de qualité
        │
        └── Références de qualité
```

Cette séparation est conservée dans :

- les KPI ;
- les calculs ;
- les graphiques ;
- les interactions ;
- l'interprétation des résultats.

Les règles utilisées pour déterminer les dépassements proviennent des **règles associées aux observations dans les données Hub'Eau**.

Les seuils ne sont pas codés comme des valeurs fixes par paramètre dans le dashboard, car leur exploration a montré qu'une règle peut varier selon les observations.

Les analyses ayant conduit à ces choix sont détaillées dans [`reflexion_KPIs.md`](../reflexion_KPIs.md).

---

## 4. Organisation de la page

La page est organisée selon quatre niveaux de lecture :

```text
1. Filtres
        │
        ▼
2. Synthèse des dépassements
        │
        ▼
3. Dépassements par paramètre
        │
        ▼
4. Évolution temporelle
```

Cette organisation doit permettre de répondre progressivement aux questions :

```text
Combien de résultats sont analysés ?
        │
        ▼
Existe-t-il des dépassements ?
        │
        ▼
Quels paramètres sont concernés ?
        │
        ▼
À quelles périodes ?
```

---

## 5. Filtres

Les filtres principaux de la Page 2 sont :

```text
Période
Paramètre
Installation
Réseau
Lieu d'analyse
```

Ils doivent agir sur les indicateurs et visualisations lorsque leur utilisation est compatible avec le grain analytique concerné.

---

### 5.1 Période

Le filtre **Période** permet de restreindre l'analyse à une période donnée.

Il s'appuie sur la dimension :

`dim_date`

Il doit agir sur :

- le nombre de résultats analysés ;
- les KPI de limites de qualité ;
- les KPI de références de qualité ;
- le graphique des dépassements par paramètre ;
- le graphique d'évolution temporelle.

L'analyse temporelle est présentée à l'**année par défaut**, avec possibilité de descendre jusqu'au **mois**.

---

### 5.2 Paramètre

Le filtre **Paramètre** permet de sélectionner un ou plusieurs paramètres parmi les paramètres du périmètre étudié.

Il s'appuie sur :

`dim_parametre`

Contrairement à la Page 1, ce filtre est pertinent ici car le paramètre appartient directement au niveau d'analyse des résultats.

Lorsqu'un paramètre est sélectionné, les indicateurs et graphiques doivent être recalculés uniquement sur les résultats correspondant à cette sélection.

La sélection d'un paramètre peut conduire à l'absence de règle de qualité évaluable pour l'une des deux familles.

Ce cas ne doit pas être interprété comme un taux de dépassement égal à zéro.

La règle correspondante est détaillée dans la section **11 - Distinction entre absence de dépassement et absence de règle évaluable**.

---

### 5.3 Installation

Le filtre **Installation** permet d'analyser les résultats selon l'installation amont associée au prélèvement.

Il s'appuie sur :

`dim_installation`

Il doit permettre de déterminer si les dépassements observés se concentrent sur certaines installations.

---

### 5.4 Réseau

Le filtre **Réseau** permet d'analyser les résultats associés aux prélèvements desservant un réseau sélectionné.

Le réseau n'est pas directement porté par `fact_resultats`.

La relation est connue au niveau du prélèvement grâce à :

`bridge_prelevements_reseaux`

Le principe fonctionnel retenu est :

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

L'implémentation Power BI devra préserver le grain de `fact_resultats` et empêcher qu'un résultat soit comptabilisé plusieurs fois du fait de la relation plusieurs-à-plusieurs entre prélèvements et réseaux.

---

### 5.5 Lieu d'analyse

Le filtre **Lieu d'analyse** repose sur :

`code_lieu_analyse`

Il permet de distinguer les résultats selon leur lieu d'analyse.

Ce filtre est pertinent sur la Page 2 car le lieu d'analyse appartient directement au grain de `fact_resultats`.

Il ne doit pas être confondu avec un attribut du prélèvement dans son ensemble.

---

## 6. Indicateur de contexte

La partie supérieure de la page présente un indicateur simple :

```text
X résultats analysés
```

Cet indicateur représente le volume de résultats correspondant à la sélection active.

Il fournit un contexte sur le volume de données analysé avant l'interprétation des KPI de dépassement.

Il est volontairement distinct des nombres de **résultats évaluables** pour les limites et les références de qualité.

En effet :

```text
Résultats analysés
        ≠
Résultats évaluables pour une limite
        ≠
Résultats évaluables pour une référence
```

Un résultat peut être présent dans le périmètre analytique sans disposer d'une règle de qualité permettant son évaluation pour l'une des deux familles.

---

## 7. Synthèse des dépassements

### 7.1 Présentation retenue

Deux blocs KPI sont affichés côte à côte :

```text
┌─────────────────────────────┐  ┌─────────────────────────────┐
│ LIMITES DE QUALITÉ          │  │ RÉFÉRENCES DE QUALITÉ      │
│                             │  │                             │
│           X %               │  │           X %               │
│      de dépassement         │  │      de dépassement         │
│                             │  │                             │
│ X résultats évaluables      │  │ X résultats évaluables      │
│ Y dépassements              │  │ Y dépassements              │
└─────────────────────────────┘  └─────────────────────────────┘
```

Le premier bloc concerne uniquement les **limites de qualité**.

Le second concerne uniquement les **références de qualité**.

Cette présentation permet de comparer les deux familles sans les fusionner.

---

### 7.2 Informations affichées

Chaque bloc affiche :

1. le **taux de dépassement** ;
2. le **nombre de résultats évaluables** ;
3. le **nombre de dépassements**.

Le taux permet de mesurer la fréquence relative des dépassements.

Le nombre de dépassements permet de conserver une lecture en volume.

Le nombre de résultats évaluables fournit le dénominateur nécessaire à l'interprétation du taux.

---

## 8. Règle de calcul des taux

Pour chaque famille de règles :

**Taux de dépassement = Nombre de résultats dépassant la règle / Nombre de résultats évaluables**

Un résultat est considéré comme **évaluable** uniquement lorsqu'il dispose des informations nécessaires pour appliquer la règle correspondante.

Les résultats non mesurés tels que :

`N.M.`

ne doivent pas être intégrés artificiellement au dénominateur lorsqu'ils ne permettent pas l'évaluation de la règle.

La logique d'évaluation utilise les informations structurées présentes dans `fact_resultats`, notamment :

- opérateur minimum ;
- valeur minimum ;
- opérateur maximum ;
- valeur maximum ;
- résultat numérique exploitable pour l'évaluation.

Les règles sont évaluées au niveau de chaque observation.

Cette approche permet notamment de prendre en compte les situations dans lesquelles un même paramètre peut être associé à des seuils différents selon les observations.

---

## 9. Sélecteur du type de règle

Les analyses détaillées sont pilotées par un sélecteur :

```text
[ Limites de qualité ]   [ Références de qualité ]
```

Ce sélecteur permet de choisir la famille de règles étudiée.

Il pilote :

- le graphique **Dépassements par paramètre** ;
- le graphique **Évolution des dépassements**.

Le sélecteur ne fusionne jamais les deux familles.

Il permet uniquement de choisir laquelle est utilisée pour les analyses détaillées.

---

## 10. Graphique - Dépassements par paramètre

### 10.1 Objectif

Ce graphique répond à la question :

> **Quels paramètres présentent des dépassements et à quelle fréquence ?**

La visualisation retenue est un **graphique en barres horizontales**.

Exemple fonctionnel :

```text
DÉPASSEMENTS PAR PARAMÈTRE

Paramètre A  ███████████████████  X %
Paramètre B  ███████████          X %
Paramètre C  ████                 X %
Paramètre D                       0 %
```

L'indicateur principal représenté par la longueur de la barre est le :

**Taux de dépassement par paramètre**

Le taux est privilégié au nombre brut de dépassements car le nombre de résultats évaluables peut différer entre paramètres.

Comparer uniquement les volumes pourrait donc conduire à une interprétation incorrecte.

---

### 10.2 Informations complémentaires

L'infobulle associée à chaque paramètre doit présenter au minimum :

```text
Paramètre : X
Type de règle : Limite / Référence
Résultats évaluables : X
Dépassements : Y
Taux de dépassement : X %
```

Le nombre absolu de dépassements reste ainsi accessible sans surcharger le graphique principal.

---

### 10.3 Paramètres sans dépassement

Un paramètre disposant de résultats évaluables mais ne présentant aucun dépassement peut être affiché avec :

```text
0 %
```

Dans ce cas, `0 %` signifie explicitement :

> **Le paramètre a été évalué pour la règle considérée et aucun dépassement n'a été observé.**

Cette situation doit être distinguée d'un paramètre pour lequel aucune règle n'est évaluable.

---

## 11. Distinction entre absence de dépassement et absence de règle évaluable

Cette distinction constitue une règle fonctionnelle importante de la Page 2.

### 11.1 Principe

L'absence de règle évaluable ne doit jamais être assimilée à une absence de dépassement.

Les situations suivantes ont des significations différentes :

| Situation | Affichage attendu |
|---|---|
| Règle évaluable et dépassement(s) observé(s) | `X %` et `Y dépassements` |
| Règle évaluable mais aucun dépassement observé | `0 %` et `0 dépassement` |
| Aucune règle évaluable pour la sélection | `Non évaluable` et `—` |

La distinction fondamentale est donc :

```text
0 % de dépassement
        ≠
absence de règle évaluable
```

---

### 11.2 Comportement des cartes KPI

Un taux de `0 %` ne peut être affiché que lorsqu'au moins un résultat est effectivement évaluable pour la famille de règles considérée et qu'aucun dépassement n'est observé.

Si :

```text
Nombre de résultats évaluables > 0
```

le taux est calculé normalement.

Si :

```text
Nombre de résultats évaluables = 0
```

le taux ne doit pas être calculé comme `0 %`.

La carte affiche :

```text
Non évaluable

0 résultat évaluable
— dépassement
```

Le symbole `—` est préféré à `0` pour le nombre de dépassements dans cette situation.

`0` constituerait un résultat analytique et pourrait être interprété comme l'observation effective d'une absence de dépassement.

`—` indique au contraire que cet indicateur n'est pas calculable pour la sélection actuelle.

---

### 11.3 Exemple fonctionnel

Si un paramètre sélectionné possède des résultats mais aucune règle de la famille considérée :

```text
┌─────────────────────────────┐
│ LIMITES DE QUALITÉ          │
│                             │
│       Non évaluable         │
│                             │
│ 0 résultat évaluable        │
│ — dépassement               │
└─────────────────────────────┘
```

Cette présentation ne signifie pas que le paramètre respecte nécessairement une limite.

Elle signifie uniquement :

> **Les données disponibles dans la sélection actuelle ne permettent pas d'évaluer ce KPI pour cette famille de règles.**

---

### 11.4 Comportement du graphique par paramètre

Un paramètre sans règle évaluable pour le type sélectionné ne doit pas être représenté artificiellement avec une barre à `0 %`.

Une barre à `0 %` est réservée aux paramètres :

- disposant d'au moins un résultat évaluable ;
- ne présentant aucun dépassement parmi ces résultats.

Les paramètres non évaluables sont donc distincts des paramètres évalués sans dépassement.

---

### 11.5 Comportement lorsqu'aucune donnée n'est évaluable

Si la sélection active ne contient aucun résultat évaluable pour le type de règle choisi, les visualisations concernées doivent afficher un état vide explicite plutôt qu'une série de valeurs nulles ou de zéros.

Message fonctionnel proposé :

> **Aucune règle de qualité évaluable pour la sélection actuelle.**

Cette règle évite de transformer une absence d'information analytique en résultat de conformité implicite.

---

## 12. Graphique : Évolution des dépassements

### 12.1 Objectif

Ce graphique répond à la question :

> **À quelles périodes les dépassements ont-ils été observés ?**

Il permet d'analyser simultanément :

- la fréquence relative des dépassements ;
- leur nombre absolu.

---

### 12.2 Visualisation retenue

La visualisation retenue est un **graphique combiné** :

- **courbe** : taux de dépassement ;
- **colonnes** : nombre de dépassements.

Exemple fonctionnel :

```text
ÉVOLUTION DES DÉPASSEMENTS

Taux
 │
X%│              ●
 │             /   \
 │      ●─────●     ●
 │     /             \
 │  ●─●               ●
 │
 └──────────────────────────────► Période

Colonnes → nombre de dépassements
Courbe   → taux de dépassement
```

Les deux informations sont complémentaires.

Le taux permet de comparer les périodes même lorsque le nombre de résultats évaluables varie.

Le nombre absolu permet de connaître le volume réel de dépassements observés.

---

### 12.3 Granularité temporelle

Le niveau temporel affiché par défaut est :

`Année`

L'utilisateur doit pouvoir descendre jusqu'au :

`Mois`

La navigation suit donc :

```text
Année
  │
  ▼
Mois
```

L'année est privilégiée comme niveau initial afin de conserver une lecture globale et d'éviter une visualisation excessivement fragmentée lorsque les dépassements sont rares.

---

## 13. Interactions entre les visualisations

La Page 2 doit permettre une investigation progressive.

Le parcours analytique attendu est :

```text
Vue globale des dépassements
        │
        ▼
Identification d'un paramètre
        │
        ▼
Sélection du paramètre
        │
        ▼
Analyse des périodes concernées
```

Lorsqu'un paramètre est sélectionné dans le graphique **Dépassements par paramètre**, le graphique **Évolution des dépassements** doit pouvoir être filtré sur ce paramètre.

L'utilisateur peut ainsi passer d'une comparaison globale entre paramètres à l'analyse temporelle d'un paramètre particulier.

Le sélecteur :

```text
[ Limites de qualité ]   [ Références de qualité ]
```

doit modifier simultanément les deux graphiques détaillés afin de préserver une lecture cohérente.

---

## 14. Comportement attendu des filtres

Les filtres doivent respecter le grain résultat de la page.

Le comportement attendu est :

```text
Période
   ↓
filtre les résultats selon leur date

Paramètre
   ↓
filtre les résultats du ou des paramètres sélectionnés

Installation
   ↓
filtre les résultats associés aux prélèvements de l'installation

Lieu d'analyse
   ↓
filtre directement les résultats selon code_lieu_analyse

Réseau
   ↓
identifie les prélèvements associés au réseau
   ↓
conserve les résultats de ces prélèvements
   ↓
sans duplication des résultats
```

Le filtrage par réseau devra faire l'objet d'une attention particulière lors de l'implémentation du modèle Power BI en raison de la relation plusieurs-à-plusieurs entre prélèvements et réseaux.

---

## 15. Traitement des résultats censurés et non mesurés

La Page 2 utilise les résultats pour déterminer le respect ou le dépassement des règles de qualité.

Les résultats censurés tels que :

`<0,10`

ne doivent pas être interprétés automatiquement comme des mesures exactes égales à zéro.

Cependant, leur représentation structurée peut être utilisée pour déterminer leur position par rapport à une règle lorsque cette classification est analytiquement justifiée.

Les vérifications réalisées sur le périmètre actuel ont permis de contrôler le comportement de ces valeurs pour les règles de qualité étudiées.

Les résultats :

`N.M.`

sont considérés comme non exploitables numériquement et ne doivent pas être classés artificiellement comme respectant ou dépassant une règle.

Cette logique de classification est distincte de l'analyse statistique des valeurs mesurées qui sera développée dans la **Page 3 — Analyse des paramètres**.

Ainsi :

```text
Classification par rapport à une règle
        ≠
Analyse statistique de la mesure
```

Une valeur censurée peut fournir une information suffisante pour certaines classifications sans pour autant constituer une mesure exacte utilisable comme telle dans une moyenne, une médiane ou une autre statistique descriptive.

Les choix méthodologiques associés sont détaillés dans [`reflexion_KPIs.md`](../reflexion_KPIs.md).

---

## 16. Maquette fonctionnelle simplifiée

```text
┌───────────────────────────────────────────────────────────────────┐
│ PAGE 2 — DÉPASSEMENTS DES RÈGLES DE QUALITÉ                      │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│ Période │ Paramètre │ Installation │ Réseau │ Lieu d'analyse     │
│                                                                   │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│                     X résultats analysés                          │
│                                                                   │
│ ┌────────────────────────────┐  ┌────────────────────────────┐    │
│ │ LIMITES DE QUALITÉ         │  │ RÉFÉRENCES DE QUALITÉ     │    │
│ │                            │  │                            │    │
│ │          X %               │  │          X %               │    │
│ │     de dépassement         │  │     de dépassement         │    │
│ │                            │  │                            │    │
│ │ X résultats évaluables     │  │ X résultats évaluables     │    │
│ │ Y dépassements             │  │ Y dépassements             │    │
│ └────────────────────────────┘  └────────────────────────────┘    │
│                                                                   │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│          [ Limites de qualité │ Références de qualité ]           │
│                                                                   │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│                  DÉPASSEMENTS PAR PARAMÈTRE                       │
│                                                                   │
│ Paramètre A  ████████████████████  X %                            │
│ Paramètre B  ███████████           X %                            │
│ Paramètre C  ████                  X %                            │
│ Paramètre D                        0 %                            │
│                                                                   │
│ Infobulle : évaluables · dépassements · taux                      │
│                                                                   │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│                  ÉVOLUTION DES DÉPASSEMENTS                       │
│                                                                   │
│     Colonnes → nombre de dépassements                             │
│     Courbe   → taux de dépassement                                │
│                                                                   │
│     Année par défaut → navigation jusqu'au mois                   │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

En cas d'absence de règle évaluable pour la sélection, les zones concernées doivent remplacer les taux et graphiques non calculables par un état explicite :

```text
Non évaluable

0 résultat évaluable
— dépassement

Aucune règle de qualité évaluable
pour la sélection actuelle.
```

---

## 17. Résultat attendu

La Page 2 doit permettre à l'utilisateur de passer d'une vision synthétique des règles de qualité à une investigation détaillée des dépassements.

Elle doit permettre de répondre successivement à :

```text
Combien de résultats sont analysés ?
        │
        ▼
Quel est le niveau de dépassement
des limites et des références ?
        │
        ▼
Quels paramètres sont concernés ?
        │
        ▼
À quelles périodes ?
```

La page doit conserver plusieurs principes analytiques fondamentaux :

- ne pas fusionner les limites et les références de qualité ;
- calculer les taux uniquement sur les résultats réellement évaluables ;
- ne pas assimiler un résultat `N.M.` à un résultat conforme ;
- ne pas assimiler une absence de règle évaluable à un taux de dépassement de `0 %` ;
- distinguer les paramètres évalués sans dépassement des paramètres non évaluables ;
- préserver le grain des résultats lors du filtrage par réseau ;
- utiliser les règles associées aux observations plutôt que des seuils fixes arbitraires ;
- conserver la distinction entre classification par rapport à une règle et analyse statistique des mesures.

La Page 2 constitue ainsi le niveau de **diagnostic des dépassements** du dashboard.

Elle complète la vision globale de la **Page 1 : Conformité des prélèvements** et prépare l'analyse détaillée des valeurs mesurées qui sera développée dans la **Page 3 : Analyse des paramètres**.
