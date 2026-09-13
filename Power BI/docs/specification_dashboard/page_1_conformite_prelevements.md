# Page 1 : Conformité des prélèvements

## 1. Objectif de la page

Cette page constitue la **vue d'entrée du dashboard Power BI**.

Elle répond à la question métier suivante :

> **Quel est le niveau de conformité des prélèvements d'eau potable sur le périmètre étudié, et comment évolue-t-il dans le temps ?**

L'objectif est de fournir une vision synthétique de la conformité des prélèvements avant de poursuivre vers l'analyse des dépassements et des paramètres dans les pages suivantes du dashboard.

Cette page reste volontairement au niveau du **prélèvement**. Elle ne cherche donc pas à analyser le comportement individuel d'un paramètre.

Les valeurs présentées dans cette spécification sont représentées par des variables (`X`, `Y`, `X %`). Les résultats réels seront calculés et affichés dans le dashboard Power BI.

---

## 2. Source et grain analytique

**Table principale :** `fact_prelevements`

**Grain :**

> 1 ligne = 1 prélèvement

Les indicateurs de cette page doivent conserver ce grain, y compris lorsqu'un filtre réseau est appliqué.

Les informations détaillées relatives aux résultats des paramètres, présentes dans `fact_resultats`, ne constituent pas le grain principal de cette page.

---

## 3. Organisation de la page

La page est organisée en trois niveaux de lecture :

1. **Contexte et filtres**
2. **Synthèse de la conformité**
3. **Évolution temporelle**

Le parcours de lecture est donc :

**Périmètre analysé → Situation globale → Évolution dans le temps**

---

## 4. Filtres

Trois filtres principaux sont retenus.

### 4.1 Période

Permet de sélectionner la période étudiée.

La dimension temporelle repose sur `dim_date`.

L'analyse temporelle sera présentée **par année par défaut**, avec possibilité de descendre au niveau mensuel.

### 4.2 Installation

Permet de limiter l'analyse aux prélèvements associés à une installation donnée.

La dimension utilisée est `dim_installation`.

### 4.3 Réseau

Permet d'analyser les prélèvements associés à un réseau donné.

Le filtrage repose sur la relation :

`dim_reseau → bridge_prelevements_reseaux → fact_prelevements`

Un prélèvement pouvant être associé à plusieurs réseaux, l'utilisation de la bridge ne doit pas entraîner de double comptage.

Les indicateurs doivent donc continuer à compter les prélèvements au niveau de leur identifiant distinct.

### 4.4 Filtres volontairement absents

Les filtres **Paramètre** et **Lieu d'analyse** ne sont pas proposés sur cette page.

Ils concernent principalement les résultats détaillés de `fact_resultats`, alors que cette page analyse la conformité globale au niveau du prélèvement.

Un filtre sur un paramètre ne doit notamment pas modifier un indicateur de conformité globale provenant de `fact_prelevements`.

---

## 5. Indicateur de contexte

Un indicateur présente le :

### Nombre total de prélèvements

La valeur affichée dépend des filtres actifs sur la page.

Cet indicateur permet de connaître immédiatement le volume de prélèvements correspondant au périmètre actuellement analysé.

Aucun KPI unique **« nombre de prélèvements évaluables »** n'est présenté au niveau global, car le nombre de prélèvements évaluables peut différer selon le type de contrôle.

---

## 6. Synthèse de la conformité

La conformité est analysée selon quatre axes distincts :

1. **Limites bactériologiques**
2. **Limites physico-chimiques**
3. **Références bactériologiques**
4. **Références physico-chimiques**

Ces quatre axes ne sont pas fusionnés dans un taux global unique.

Chaque axe conserve son propre nombre de prélèvements évaluables et son propre taux de conformité.

### 6.1 Présentation retenue

Quatre cartes KPI compactes sont organisées en grille `2 × 2`.

La première ligne présente les **limites de qualité**.

La seconde ligne présente les **références de qualité**.

    ┌─────────────────────────────┐  ┌─────────────────────────────┐
    │ LIMITES BACTÉRIOLOGIQUES    │  │ LIMITES PHYSICO-CHIMIQUES  │
    │                             │  │                             │
    │            X %              │  │            X %              │
    │       de conformité         │  │       de conformité         │
    │                             │  │                             │
    │  X évaluables               │  │  X évaluables               │
    │  Y non conformes            │  │  Y non conformes            │
    └─────────────────────────────┘  └─────────────────────────────┘

    ┌─────────────────────────────┐  ┌─────────────────────────────┐
    │ RÉFÉRENCES BACTÉRIOLOGIQUES │  │ RÉFÉRENCES PHYSICO-CHIM.   │
    │                             │  │                             │
    │            X %              │  │            X %              │
    │       de conformité         │  │       de conformité         │
    │                             │  │                             │
    │  X évaluables               │  │  X évaluables               │
    │  Y non conformes            │  │  Y non conformes            │
    └─────────────────────────────┘  └─────────────────────────────┘

### 6.2 Informations affichées

Chaque carte présente :

- le **taux de conformité** ;
- le **nombre de prélèvements évaluables** ;
- le **nombre de prélèvements non conformes**.

Le nombre de prélèvements non conformes est affiché en complément du taux afin qu'un pourcentage de conformité élevé ne masque pas la présence d'événements rares.

---

## 7. Règle de calcul des taux

Pour chacun des quatre axes :

**Taux de conformité = Nombre de prélèvements C / (Nombre de prélèvements C + Nombre de prélèvements N)**

Les statuts `C` et `N` constituent le périmètre évaluable du KPI :

- `C` : prélèvement conforme ;
- `N` : prélèvement non conforme.

Le statut `S` est conservé comme une catégorie distincte et n'est pas intégré au dénominateur du taux de conformité.

Ce choix constitue une **convention analytique prudente**. Lors de l'étude de la documentation publique officielle de l'API Hub'Eau, aucune définition explicite permettant d'associer avec certitude le code `S` à une signification précise n'a été identifiée pour les champs de conformité sanitaire utilisés dans cette analyse.

En conséquence, le statut `S` n'est assimilé ni à un prélèvement conforme (`C`), ni à un prélèvement non conforme (`N`). Il est conservé dans les données mais exclu du calcul du taux afin de ne pas introduire d'interprétation non documentée.

Cette décision et l'exploration ayant conduit à cette règle sont détaillées dans [`reflexion_KPIs.md`](../reflexion_KPIs.md).
---

## 8. Évolution temporelle de la conformité

La partie inférieure de la page permet d'analyser l'évolution de la conformité dans le temps.

L'objectif est de compléter les cartes de synthèse afin d'identifier les périodes durant lesquelles des non-conformités apparaissent.

### 8.1 Sélection du type de contrôle

L'utilisateur peut sélectionner l'un des quatre axes :

- limites bactériologiques ;
- limites physico-chimiques ;
- références bactériologiques ;
- références physico-chimiques.

Le graphique temporel est mis à jour selon le type de contrôle sélectionné.

Cette approche évite de superposer les quatre taux de conformité et les différents volumes de non-conformités dans une même visualisation.

Les quatre cartes KPI restent néanmoins visibles simultanément afin de conserver une vue comparative de la situation globale.

---

## 9. Graphique : Évolution de la conformité

Le graphique temporel présente deux informations complémentaires :

- le **taux de conformité dans le temps** ;
- le **nombre de prélèvements non conformes** pour chaque période.

La vue initiale utilise une granularité **annuelle**.

Une navigation temporelle permet ensuite de descendre au niveau **mensuel** pour analyser plus précisément une période particulière.

Schéma fonctionnel :

    Taux de conformité
          │
    100 % ─────────────────────────────────
     99 % ─────●──────●─────●─────────────
     98 % ──●───────────────────●──────────
          2016   2017   2018   ...   2026

             ▂      ▃      ▂           ▅
             ↑
       Nombre de prélèvements
          non conformes

Le taux permet d'observer la tendance générale tandis que le nombre de non-conformités permet de visualiser le volume réel associé à chaque période.

---

## 10. Comportement attendu des filtres

Les filtres **Période**, **Installation** et **Réseau** doivent mettre à jour :

- le nombre total de prélèvements ;
- les quatre cartes de conformité ;
- le graphique d'évolution temporelle.

Le sélecteur du type de contrôle agit uniquement sur le graphique temporel.

Les quatre cartes de conformité restent visibles simultanément.

Le filtrage par réseau doit respecter le grain du prélèvement et ne doit pas provoquer de double comptage lié aux associations présentes dans `bridge_prelevements_reseaux`.

---

## 11. Maquette fonctionnelle simplifiée

    ┌─────────────────────────────────────────────────────────────┐
    │ PAGE 1 — CONFORMITÉ DES PRÉLÈVEMENTS                       │
    │                                                             │
    │ Période          Installation          Réseau               │
    └─────────────────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────────────┐
    │ Nombre total de prélèvements : X                            │
    └─────────────────────────────────────────────────────────────┘

    ┌────────────────────────────┐  ┌─────────────────────────────┐
    │ Limites bactériologiques   │  │ Limites physico-chimiques  │
    │ X %                        │  │ X %                         │
    │ X évaluables               │  │ X évaluables               │
    │ Y non conformes            │  │ Y non conformes            │
    └────────────────────────────┘  └─────────────────────────────┘

    ┌────────────────────────────┐  ┌─────────────────────────────┐
    │ Références bactériologiques│  │ Références physico-chim.   │
    │ X %                        │  │ X %                         │
    │ X évaluables               │  │ X évaluables               │
    │ Y non conformes            │  │ Y non conformes            │
    └────────────────────────────┘  └─────────────────────────────┘

    ┌─────────────────────────────────────────────────────────────┐
    │ Type de contrôle : [ Sélection ]                            │
    │                                                             │
    │ ÉVOLUTION DE LA CONFORMITÉ                                  │
    │                                                             │
    │ Taux de conformité + nombre de non-conformités              │
    │                                                             │
    │ Granularité : Année → Mois                                  │
    └─────────────────────────────────────────────────────────────┘

---

## 12. Résultat attendu

Cette première page doit permettre à l'utilisateur de répondre rapidement à trois questions :

1. **Combien de prélèvements sont concernés par le périmètre sélectionné ?**
2. **Quel est le niveau de conformité pour chacun des quatre types de contrôle ?**
3. **Comment la conformité et le nombre de non-conformités évoluent-ils dans le temps ?**

Elle constitue ainsi le point d'entrée du dashboard avant de poursuivre vers :

- la **Page 2 : Dépassements des règles de qualité** ;
- la **Page 3 : Analyse des paramètres**.
