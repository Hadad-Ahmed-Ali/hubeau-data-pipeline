
# Guide d'utilisation du dashboard Power BI

Ce dashboard permet d'explorer la qualité de l'eau potable à Orléans à travers trois pages complémentaires.

**[📥 Consulter le rapport Power BI (.pbix)](Power%20BI/dashboard/dashboard_qualite_eau_potable.pbix)**

## Navigation générale

- Utiliser les onglets en bas du rapport pour passer d'une page à l'autre.
- Utiliser les filtres en haut à droite pour définir le périmètre d'analyse.
- Survoler les graphiques pour consulter les informations complémentaires dans les info-bulles.
- Modifier ou effacer les sélections pour revenir à une vue plus globale.

## Page 1 - Conformité des prélèvements

**Objectif :** suivre le niveau de conformité des prélèvements.

1. Filtrer les données par **période, réseau ou installation**.
2. Consulter les quatre cartes de conformité : limites et références de qualité, bactériologiques et physico-chimiques.
3. Choisir un **type de contrôle** pour actualiser le graphique d'évolution.
4. Observer le nombre de prélèvements non conformes et le taux de conformité par période.

## Page 2 - Dépassements des règles de qualité

**Objectif :** identifier les paramètres concernés par des dépassements.

1. Utiliser les filtres **période, paramètre, réseau, installation et lieu d'analyse**.
2. Consulter les indicateurs de dépassement des **limites** et des **références** de qualité.
3. Choisir un **type de règle** pour actualiser les deux graphiques.
4. Examiner les paramètres présentant des dépassements, puis leur évolution temporelle.

**Attention :** un paramètre absent du graphique n'est pas nécessairement conforme ; il peut aussi ne pas disposer de règle évaluable.

## Page 3 - Analyse des paramètres

**Objectif :** analyser les mesures et leur évolution temporelle.

1. Sélectionner **un seul paramètre** et ajuster les autres filtres si nécessaire.
2. Consulter la répartition des résultats : **valeurs directes, censurés et N.M.**, ainsi que le taux de censure.
3. Examiner la **médiane, la moyenne et le maximum** calculés uniquement sur les valeurs directes.
4. Analyser les deux graphiques : évolution de la médiane et nombre de résultats censurés par période.

**Attention :** les résultats censurés ne sont pas considérés comme des valeurs exactes dans les statistiques descriptives.

## Parcours de lecture conseillé

**Page 1 - Conformité globale → Page 2 - Dépassements → Page 3 - Analyse détaillée des paramètres**

Ce parcours permet de passer d'une vision générale de la qualité de l'eau à une analyse plus précise des résultats.
