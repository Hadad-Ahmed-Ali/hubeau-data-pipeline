# Réflexion et définition des KPIs

## 1. Objectif

Cette étape a pour objectif de définir les indicateurs qui alimenteront le dashboard Power BI du projet **Hub'Eau Data Pipeline**.

La définition des KPIs est réalisée avant la conception des visualisations afin de partir des **questions métier**, du **grain réel des données** et des règles de qualité présentes dans les données Hub'Eau.

Le dashboard doit permettre de répondre à trois questions principales :

1. **Quel est le niveau de conformité des prélèvements d'eau potable sur le périmètre étudié, et comment évolue-t-il dans le temps ?**
2. **Quels paramètres présentent des dépassements de limites ou de références de qualité, à quelle fréquence et à quelles périodes ?**
3. **Comment évoluent les valeurs mesurées des différents paramètres dans le temps, en tenant compte de la nature directe ou censurée des résultats ?**

Ces trois questions correspondent à trois niveaux complémentaires d'analyse :

| Axe d'analyse | Objectif | Source principale |
|---|---|---|
| Conformité des prélèvements | Donner une vision sanitaire globale des prélèvements | `fact_prelevements` |
| Dépassements par paramètre | Identifier les paramètres et périodes associés à des dépassements | `fact_resultats` |
| Évolution des paramètres | Étudier le comportement des mesures dans le temps | `fact_resultats` |

---

## 2. Principes de conception

### 2.1 Respecter le grain des tables

Le modèle analytique distingue deux grains principaux.

#### Prélèvement

Dans `fact_prelevements` :

> **1 ligne = 1 prélèvement**

Cette table porte notamment les informations de conformité globale du prélèvement.

#### Résultat

Dans `fact_resultats` :

> **1 ligne = 1 résultat d'un paramètre donné, pour un prélèvement donné et un lieu d'analyse donné**

Cette table est utilisée pour analyser les mesures, les paramètres et les dépassements de règles de qualité.

Cette séparation permet d'éviter de calculer un indicateur à partir d'une table dont le grain ne correspond pas à la question métier.

---

## 3. Limites et références de qualité

Les données Hub'Eau distinguent deux types de règles qui sont volontairement analysés séparément dans le dashboard :

- **limites de qualité** ;
- **références de qualité**.

Sur le périmètre étudié, les règles présentes dans les données sont les suivantes :

| Paramètre | Limite de qualité | Référence de qualité |
|---|---|---|
| Turbidité | — | `<= 2 NFU` |
| Température | — | `<= 25 °C` |
| pH | — | `>= 6,5 et <= 9 unité pH` |
| Conductivité | — | `>= 200 et <= 1100 µS/cm` |
| Ammonium | — | `<= 0,1 mg/L` |
| Nitrites | `<= 0,1 mg/L` ou `<= 0,5 mg/L` | — |
| Nitrates | `<= 50 mg/L` | — |
| Fer | — | `<= 200 µg/L` |
| Manganèse | — | `<= 50 µg/L` |
| Chlore libre | — | — |
| Escherichia coli | `<= 0 n/(100mL)` | — |
| Entérocoques | `<= 0 n/(100mL)` | — |

Le chlore libre ne possède donc ni limite ni référence renseignée dans les données du périmètre étudié.

### 3.1 Règles dynamiques

Les seuils ne sont pas codés en dur dans la logique analytique.

Ils sont lus directement depuis les règles associées à chaque résultat dans `fact_resultats`.

Cette décision est notamment justifiée par les nitrites : deux limites différentes sont présentes dans les données :

- `<= 0,1 mg/L` ;
- `<= 0,5 mg/L`.

L'exploration montre que ces deux règles sont associées à des installations différentes sur le périmètre étudié. La règle applicable doit donc être évaluée au niveau du résultat plutôt que définie globalement pour le paramètre.

---

## 4. Question métier 1 — Conformité des prélèvements

### 4.1 Question

> **Quel est le niveau de conformité des prélèvements d'eau potable sur le périmètre étudié, et comment évolue-t-il dans le temps ?**

### 4.2 Grain et source

**Grain :**

> 1 ligne = 1 prélèvement

**Table principale :**

`fact_prelevements`

Les quatre axes de conformité disponibles sont :

- limites bactériologiques ;
- limites physico-chimiques ;
- références bactériologiques ;
- références physico-chimiques.

### 4.3 Distribution observée

| Type de contrôle | Conforme (`C`) | Non conforme (`N`) | Statut `S` |
|---|---:|---:|---:|
| Limites bactériologiques | 1 906 | 3 | 5 |
| Limites physico-chimiques | 1 911 | 3 | 0 |
| Références bactériologiques | 1 900 | 9 | 5 |
| Références physico-chimiques | 1 867 | 47 | 0 |

Les champs de conformité utilisent principalement les codes `C`, `N` et, dans certains cas, `S`.

Les conclusions textuelles associées aux prélèvements sont conservées pour apporter du contexte, mais ne sont pas utilisées directement pour calculer les KPIs. Elles contiennent de nombreuses formulations différentes et ne constituent donc pas une catégorie analytique suffisamment stable.

### 4.4 Traitement du statut `S`

Les valeurs `C` et `N` permettent de distinguer les prélèvements conformes et non conformes.

Le statut `S` est conservé comme une catégorie distincte.

Sa signification exacte n'ayant pas été établie de manière suffisamment explicite à partir de la documentation publique consultée, il n'est pas assimilé arbitrairement à un prélèvement conforme ou non conforme.

Il est donc exclu du dénominateur des taux calculés à partir des statuts `C` et `N`.

### 4.5 KPIs retenus

Pour chacun des quatre axes de conformité :

- nombre de prélèvements évaluables ;
- nombre de prélèvements conformes ;
- nombre de prélèvements non conformes ;
- taux de conformité.

**Formule du taux de conformité :**

`Taux de conformité = Nombre de prélèvements C / (Nombre de prélèvements C + Nombre de prélèvements N)`

#### Résultats globaux observés

| Type de contrôle | Prélèvements évaluables | Non conformes | Taux de conformité |
|---|---:|---:|---:|
| Limites bactériologiques | 1 909 | 3 | 99,84 % |
| Limites physico-chimiques | 1 914 | 3 | 99,84 % |
| Références bactériologiques | 1 909 | 9 | 99,53 % |
| Références physico-chimiques | 1 914 | 47 | 97,54 % |

Le nombre de non-conformités est conservé en complément du taux. Un pourcentage très élevé peut en effet masquer des événements rares mais importants.

### 4.6 Filtres envisagés

| Filtre | Utilisation |
|---|---|
| Période | Oui |
| Installation | Oui |
| Réseau | Oui, avec contrôle du chemin de filtrage via la bridge |
| Paramètre | Non |
| Lieu d'analyse | Non |
| Commune | Possible, mais peu discriminante sur le périmètre actuel |

Le filtre **Paramètre** ne doit pas modifier ces indicateurs : la conformité présente dans `fact_prelevements` correspond à la vision globale du prélèvement et peut concerner des paramètres qui ne font pas partie des 12 paramètres sélectionnés pour l'analyse détaillée.

---

## 5. Question métier 2 — Dépassements des règles de qualité

### 5.1 Question

> **Quels paramètres présentent des dépassements de limites ou de références de qualité, à quelle fréquence et à quelles périodes ?**

### 5.2 Grain et source

**Grain :**

> 1 résultat × 1 paramètre × 1 prélèvement × 1 lieu d'analyse

**Table principale :**

`fact_resultats`

Les limites et références sont évaluées séparément.

Un résultat entre dans le calcul lorsqu'il possède :

1. une règle de qualité correspondant à l'analyse ;
2. une valeur permettant d'évaluer cette règle.

Les résultats `N.M.` ne sont pas considérés comme des résultats conformes : ils sont exclus du nombre de résultats évaluables.

### 5.3 Limites de qualité

Les résultats observés sont :

| Paramètre | Résultats évalués | Dans la limite | Hors limite |
|---|---:|---:|---:|
| Nitrites | 366 | 366 | 0 |
| Nitrates | 311 | 311 | 0 |
| Escherichia coli | 1 908 | 1 905 | 3 |
| Entérocoques | 1 908 | 1 907 | 1 |

Au total :

- **4 493 résultats évaluables** ;
- **4 résultats hors limite**.

Les quatre dépassements correspondent à :

- E. coli : valeurs `1`, `2` et `3 n/(100mL)` ;
- Entérocoques : valeur `15 n/(100mL)`.

### 5.4 Références de qualité

| Paramètre | Résultats évalués | Dans la référence | Hors référence |
|---|---:|---:|---:|
| Turbidité | 1 910 | 1 905 | 5 |
| Température | 1 913 | 1 899 | 14 |
| pH | 2 188 | 2 188 | 0 |
| Conductivité | 1 908 | 1 908 | 0 |
| Ammonium | 1 908 | 1 907 | 1 |
| Fer | 1 839 | 1 831 | 8 |
| Manganèse | 1 833 | 1 832 | 1 |

Au total :

- **13 489 résultats évaluables** ;
- **29 résultats hors référence**.

Les dépassements de limites et les sorties de références ne sont pas additionnés pour produire un indicateur unique de « non-conformité ».

Ils correspondent à deux familles de règles différentes et restent donc analysés séparément.

### 5.5 KPIs retenus

Pour les limites :

- nombre de résultats évaluables ;
- nombre de résultats dans la limite ;
- nombre de résultats hors limite ;
- taux de dépassement de limite.

Pour les références :

- nombre de résultats évaluables ;
- nombre de résultats dans la référence ;
- nombre de résultats hors référence ;
- taux de sortie de référence.

**Formule générale :**

`Taux de dépassement = Nombre de résultats hors règle / Nombre de résultats évaluables`

Sur l'ensemble du périmètre étudié :

| Famille | Résultats évaluables | Hors règle | Taux |
|---|---:|---:|---:|
| Limites de qualité | 4 493 | 4 | 0,089 % |
| Références de qualité | 13 489 | 29 | 0,215 % |

L'analyse par paramètre reste privilégiée par rapport au seul taux global afin d'identifier l'origine des événements observés.

### 5.6 Filtres envisagés

| Filtre | Utilisation |
|---|---|
| Période | Oui |
| Paramètre | Oui |
| Installation | Oui |
| Lieu d'analyse | Oui |
| Réseau | Oui, avec contrôle du chemin de filtrage via la bridge |
| Commune | Possible, mais peu discriminante sur le périmètre actuel |

---

## 6. Question métier 3 — Évolution des paramètres

### 6.1 Question

> **Comment évoluent les valeurs mesurées des différents paramètres dans le temps, en tenant compte de la nature directe ou censurée des résultats ?**

### 6.2 Problématique des valeurs censurées

L'exploration des résultats montre que certaines mesures sont exprimées sous forme de seuil, par exemple :

- `<0,10` ;
- `<0,05` ;
- `<10` ;
- `<1`.

Dans `resultat_numerique`, ces observations peuvent être représentées par `0.0`.

Cette valeur numérique ne signifie cependant pas nécessairement que la concentration réellement mesurée est égale à zéro.

Par exemple :

`Résultat Hub'Eau : <10 µg/L`

`Valeur numérique : 0.0`

L'information disponible signifie que la valeur est inférieure à `10 µg/L`, et non qu'elle vaut nécessairement `0 µg/L`.

Une moyenne calculée directement sur `resultat_numerique` pourrait donc être trompeuse.

### 6.3 Importance de la censure selon le paramètre

| Paramètre | Valeurs directes | Valeurs censurées `<` | N.M. | Part censurée* |
|---|---:|---:|---:|---:|
| Turbidité | 1 193 | 717 | 0 | 37,5 % |
| Température | 1 913 | 0 | 1 | 0 % |
| pH | 2 188 | 0 | 17 | 0 % |
| Conductivité | 1 908 | 0 | 0 | 0 % |
| Ammonium | 8 | 1 900 | 0 | 99,6 % |
| Nitrites | 1 | 365 | 0 | 99,7 % |
| Nitrates | 265 | 46 | 0 | 14,8 % |
| Fer | 382 | 1 457 | 0 | 79,2 % |
| Manganèse | 32 | 1 801 | 0 | 98,3 % |
| Chlore libre | 1 872 | 39 | 2 | 2,0 % |
| Escherichia coli | 3 | 1 905 | 0 | 99,8 % |
| Entérocoques | 1 | 1 907 | 0 | 99,9 % |

\* Part calculée parmi les résultats hors `N.M.`.

La proportion de valeurs censurées varie fortement selon le paramètre. Les statistiques descriptives doivent donc être interprétées en tenant compte de cette information.

### 6.4 Règle analytique retenue

Les résultats sont distingués en trois catégories.

#### Valeur directe

La valeur peut être utilisée pour les statistiques descriptives.

#### Valeur censurée `<x`

La valeur est :

- conservée dans les données ;
- comptabilisée comme résultat censuré ;
- exclue des statistiques calculées sur les valeurs directes ;
- jamais assimilée automatiquement à une mesure réelle égale à zéro.

#### `N.M.`

Le résultat est :

- conservé ;
- comptabilisé séparément ;
- exclu des statistiques numériques.

Aucune transformation arbitraire du type `<x → x/2` n'est appliquée.

L'objectif est de conserver une lecture transparente des données plutôt que d'introduire une hypothèse statistique supplémentaire.

### 6.5 KPIs communs

Pour chaque paramètre sélectionné :

- nombre total de résultats ;
- nombre de valeurs directes ;
- nombre de résultats censurés ;
- part de résultats censurés ;
- nombre de résultats `N.M.` ;
- nombre de dépassements lorsqu'une règle de qualité est disponible.

### 6.6 Statistiques descriptives

Les statistiques suivantes peuvent être calculées sur les **valeurs directes uniquement** :

- moyenne des valeurs directes ;
- médiane des valeurs directes ;
- maximum direct observé.

Le nombre de valeurs directes et la part de résultats censurés doivent rester disponibles pour permettre d'interpréter correctement ces statistiques.

Par exemple, une moyenne calculée à partir de 1 913 valeurs directes de température n'a pas la même représentativité qu'une moyenne calculée à partir de seulement 8 valeurs directes d'ammonium.

Aucun seuil arbitraire de pourcentage de censure n'est utilisé pour masquer automatiquement une statistique. La représentativité est rendue visible à travers le nombre de valeurs directes et la part de résultats censurés.

### 6.7 Analyse temporelle

L'analyse temporelle doit permettre d'observer :

- l'évolution des valeurs directes ;
- les périodes présentant des variations particulières ;
- les événements de dépassement ;
- la présence de résultats censurés ;
- la règle de qualité applicable lorsqu'elle existe.

Les paramètres sont analysés séparément car leurs unités et leurs significations sont différentes.

Une valeur de pH, une température en °C, une concentration en mg/L et un résultat microbiologique en `n/(100mL)` ne peuvent pas être agrégés dans une même statistique globale.

### 6.8 Filtres envisagés

| Filtre | Utilisation |
|---|---|
| Période | Oui |
| Paramètre | Oui |
| Installation | Oui |
| Lieu d'analyse | Oui |
| Réseau | Oui, avec contrôle du chemin de filtrage via la bridge |
| Commune | Possible, mais peu discriminante sur le périmètre actuel |

---

## 7. Synthèse de la stratégie analytique

Le dashboard repose sur trois niveaux complémentaires :

**1. Conformité des prélèvements**

- Grain : prélèvement
- Source : `fact_prelevements`
- Objectif : vision sanitaire globale

**2. Dépassements par paramètre**

- Grain : résultat
- Source : `fact_resultats`
- Objectif : analyser séparément les limites et les références de qualité

**3. Évolution des paramètres**

- Grain : résultat
- Source : `fact_resultats`
- Objectif : analyser les valeurs directes, les résultats censurés et leur évolution temporelle

Cette organisation permet de passer d'une **vision globale de la conformité des prélèvements** à une **analyse détaillée des paramètres et de leurs mesures**.

---

## 8. Principales décisions analytiques

1. **Respecter le grain de chaque table** : les indicateurs de conformité des prélèvements sont calculés depuis `fact_prelevements`, tandis que les analyses par paramètre utilisent `fact_resultats`.

2. **Séparer limites et références de qualité** : elles ne sont pas fusionnées dans un indicateur générique unique.

3. **Utiliser les règles présentes au niveau du résultat** : les seuils ne sont pas codés en dur par paramètre, notamment en raison de la présence de plusieurs limites pour les nitrites.

4. **Ne pas utiliser les conclusions textuelles comme statut analytique** : les champs codifiés de conformité sont privilégiés.

5. **Conserver `S` comme statut distinct** : il n'est pas assimilé arbitrairement à `C` ou `N` dans les calculs de taux.

6. **Exclure les résultats `N.M.` des calculs numériques et des dénominateurs nécessitant une valeur évaluable**.

7. **Ne pas assimiler les résultats censurés `<x` à des mesures réelles égales à zéro**.

8. **Calculer les statistiques descriptives sur les valeurs directes uniquement**, tout en affichant le volume et la part de résultats censurés nécessaires à leur interprétation.

9. **Analyser les paramètres séparément** : leurs unités et significations ne permettent pas de construire une moyenne globale pertinente.

10. **Contrôler spécifiquement le filtrage par réseau dans Power BI** : la relation avec les prélèvements passe par `bridge_prelevements_reseaux` et doit éviter les doubles comptages.

---

## 9. Prochaine étape

Cette réflexion constitue la base fonctionnelle du dashboard.

La prochaine étape consiste à traduire ces règles dans la **spécification du dashboard Power BI** afin de définir :

- les pages du rapport ;
- les KPIs affichés sur chaque page ;
- les visualisations adaptées ;
- les filtres globaux et locaux ;
- les interactions entre les visuels ;
- la navigation entre la vision globale des prélèvements et l'analyse détaillée des paramètres.

Cette spécification sera documentée dans :

`Power BI/docs/specification_dashboard.md`
