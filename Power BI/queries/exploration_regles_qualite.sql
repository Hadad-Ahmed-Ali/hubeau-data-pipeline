-- ============================================================
-- Exploration des règles de qualité
-- Projet : Hub'Eau Data Pipeline
--
-- Objectif :
-- Vérifier les règles présentes dans fact_resultats avant
-- la définition et l'implémentation des KPIs Power BI.
--
-- Les requêtes ci-dessous documentent notamment :
-- - les règles de qualité disponibles par paramètre ;
-- - le cas particulier des nitrites ;
-- - les dépassements de limites et de références ;
-- - la présence de résultats censurés et de valeurs N.M. ;
-- - les résultats microbiologiques associés aux dépassements.
-- ============================================================


-- ============================================================
-- 1. Règles de qualité présentes par paramètre
--
-- Cette requête permet d'identifier les limites et références
-- réellement présentes dans les données.
--
-- Les seuils ne sont pas supposés fixes par paramètre :
-- ils sont observés au niveau des résultats.
-- ============================================================

SELECT
    code_parametre,
    limite_qualite_parametre,
    reference_qualite_parametre,
    COUNT(*) AS nb_resultats
FROM `project-3665c0d5-5952-473b-82e.hubeau_fact.fact_resultats`
GROUP BY
    code_parametre,
    limite_qualite_parametre,
    reference_qualite_parametre
ORDER BY
    code_parametre,
    limite_qualite_parametre,
    reference_qualite_parametre;


-- ============================================================
-- 2. Vérification du cas particulier des nitrites
--
-- Le paramètre 1339 présente deux limites dans les données :
-- <= 0,1 mg/L et <= 0,5 mg/L.
--
-- Cette requête vérifie leur répartition par installation.
-- Elle justifie l'utilisation de la règle attachée à chaque
-- résultat plutôt qu'un seuil codé en dur dans Power BI.
-- ============================================================

SELECT
    code_installation_amont,
    limite_qualite_parametre,
    COUNT(*) AS nb_resultats
FROM `project-3665c0d5-5952-473b-82e.hubeau_fact.fact_resultats`
WHERE code_parametre = '1339'
GROUP BY
    code_installation_amont,
    limite_qualite_parametre
ORDER BY
    code_installation_amont,
    limite_qualite_parametre;


-- ============================================================
-- 3. Évaluation des limites de qualité
--
-- Grain :
-- 1 ligne source = 1 résultat d'un paramètre,
-- pour un prélèvement et un lieu d'analyse donnés.
--
-- Seuls les résultats possédant une limite de qualité sont
-- étudiés.
--
-- Une valeur numérique NULL n'est pas évaluable et n'est donc
-- pas considérée comme conforme.
--
-- Les bornes structurées présentes dans fact_resultats sont
-- utilisées afin de respecter la règle propre à chaque résultat.
-- ============================================================

WITH evaluation_limites AS (

    SELECT
        code_parametre,
        resultat_alphanumerique,
        resultat_numerique,
        limite_qualite_parametre,

        CASE
            WHEN resultat_numerique IS NULL THEN NULL

            WHEN valeur_min_limite_qualite IS NOT NULL
                 AND operateur_min_limite_qualite = '>='
                 AND resultat_numerique < valeur_min_limite_qualite
                THEN FALSE

            WHEN valeur_min_limite_qualite IS NOT NULL
                 AND operateur_min_limite_qualite = '>'
                 AND resultat_numerique <= valeur_min_limite_qualite
                THEN FALSE

            WHEN valeur_max_limite_qualite IS NOT NULL
                 AND operateur_max_limite_qualite = '<='
                 AND resultat_numerique > valeur_max_limite_qualite
                THEN FALSE

            WHEN valeur_max_limite_qualite IS NOT NULL
                 AND operateur_max_limite_qualite = '<'
                 AND resultat_numerique >= valeur_max_limite_qualite
                THEN FALSE

            ELSE TRUE
        END AS respecte_limite

    FROM `project-3665c0d5-5952-473b-82e.hubeau_fact.fact_resultats`

    WHERE limite_qualite_parametre IS NOT NULL
)

SELECT
    code_parametre,
    COUNTIF(respecte_limite IS NOT NULL) AS nb_resultats_evalues,
    COUNTIF(respecte_limite = TRUE) AS nb_dans_limite,
    COUNTIF(respecte_limite = FALSE) AS nb_hors_limite
FROM evaluation_limites
GROUP BY
    code_parametre
ORDER BY
    code_parametre;


-- ============================================================
-- 4. Évaluation des références de qualité
--
-- Les références de qualité sont analysées séparément des
-- limites de qualité.
--
-- La logique d'évaluation repose également sur les bornes
-- structurées présentes au niveau de chaque résultat.
-- ============================================================

WITH evaluation_references AS (

    SELECT
        code_parametre,
        resultat_alphanumerique,
        resultat_numerique,
        reference_qualite_parametre,

        CASE
            WHEN resultat_numerique IS NULL THEN NULL

            WHEN valeur_min_reference_qualite IS NOT NULL
                 AND operateur_min_reference_qualite = '>='
                 AND resultat_numerique < valeur_min_reference_qualite
                THEN FALSE

            WHEN valeur_min_reference_qualite IS NOT NULL
                 AND operateur_min_reference_qualite = '>'
                 AND resultat_numerique <= valeur_min_reference_qualite
                THEN FALSE

            WHEN valeur_max_reference_qualite IS NOT NULL
                 AND operateur_max_reference_qualite = '<='
                 AND resultat_numerique > valeur_max_reference_qualite
                THEN FALSE

            WHEN valeur_max_reference_qualite IS NOT NULL
                 AND operateur_max_reference_qualite = '<'
                 AND resultat_numerique >= valeur_max_reference_qualite
                THEN FALSE

            ELSE TRUE
        END AS respecte_reference

    FROM `project-3665c0d5-5952-473b-82e.hubeau_fact.fact_resultats`

    WHERE reference_qualite_parametre IS NOT NULL
)

SELECT
    code_parametre,
    COUNTIF(respecte_reference IS NOT NULL) AS nb_resultats_evalues,
    COUNTIF(respecte_reference = TRUE) AS nb_dans_reference,
    COUNTIF(respecte_reference = FALSE) AS nb_hors_reference
FROM evaluation_references
GROUP BY
    code_parametre
ORDER BY
    code_parametre;


-- ============================================================
-- 5. Nature des résultats
--
-- L'objectif est de distinguer :
-- - les valeurs directes ;
-- - les résultats censurés de type "<x" ;
-- - les résultats N.M.
--
-- Cette distinction est importante car une valeur censurée
-- représentée numériquement par 0.0 ne signifie pas que la
-- mesure réelle est égale à zéro.
-- ============================================================

SELECT
    code_parametre,

    CASE
        WHEN TRIM(resultat_alphanumerique) = 'N.M.'
            THEN 'N.M.'

        WHEN STARTS_WITH(TRIM(resultat_alphanumerique), '<')
            THEN 'censure_inf'

        ELSE 'valeur_directe'
    END AS type_resultat,

    COUNT(*) AS nb_resultats

FROM `project-3665c0d5-5952-473b-82e.hubeau_fact.fact_resultats`

GROUP BY
    code_parametre,
    type_resultat

ORDER BY
    code_parametre,
    type_resultat;


-- ============================================================
-- 6. Détail des valeurs censurées
--
-- Cette requête permet de comparer :
-- - la forme alphanumérique originale ;
-- - la valeur numérique stockée ;
-- - la règle de qualité associée.
--
-- Elle sert notamment à vérifier que les résultats "<x"
-- ne doivent pas être interprétés comme des mesures réelles
-- égales à zéro dans les statistiques descriptives.
-- ============================================================

SELECT
    code_parametre,
    resultat_alphanumerique,
    resultat_numerique,
    limite_qualite_parametre,
    reference_qualite_parametre,
    COUNT(*) AS nb_resultats

FROM `project-3665c0d5-5952-473b-82e.hubeau_fact.fact_resultats`

WHERE STARTS_WITH(TRIM(resultat_alphanumerique), '<')

GROUP BY
    code_parametre,
    resultat_alphanumerique,
    resultat_numerique,
    limite_qualite_parametre,
    reference_qualite_parametre

ORDER BY
    code_parametre,
    resultat_alphanumerique;


-- ============================================================
-- 7. Vérification des résultats microbiologiques
--
-- Paramètres :
-- 1449 = Escherichia coli
-- 6455 = Entérocoques
--
-- Leur limite présente dans les données est <= 0 n/(100mL).
--
-- Cette exploration permet de vérifier les différentes formes
-- observées et d'identifier les résultats positifs responsables
-- des dépassements.
-- ============================================================

SELECT
    code_parametre,
    resultat_alphanumerique,
    resultat_numerique,
    limite_qualite_parametre,
    operateur_max_limite_qualite,
    valeur_max_limite_qualite,
    unite_limite_qualite,
    COUNT(*) AS nb_resultats

FROM `project-3665c0d5-5952-473b-82e.hubeau_fact.fact_resultats`

WHERE code_parametre IN ('1449', '6455')

GROUP BY
    code_parametre,
    resultat_alphanumerique,
    resultat_numerique,
    limite_qualite_parametre,
    operateur_max_limite_qualite,
    valeur_max_limite_qualite,
    unite_limite_qualite

ORDER BY
    code_parametre,
    resultat_numerique,
    resultat_alphanumerique;


-- ============================================================
-- 8. Répartition globale : direct / censuré / N.M.
--
-- Cette synthèse quantifie la part des résultats directement
-- utilisables pour les statistiques descriptives.
--
-- Le taux de censure est calculé parmi les résultats hors N.M.
-- ============================================================

WITH typage_resultats AS (

    SELECT
        code_parametre,

        CASE
            WHEN TRIM(resultat_alphanumerique) = 'N.M.'
                THEN 'N.M.'

            WHEN STARTS_WITH(TRIM(resultat_alphanumerique), '<')
                THEN 'censure_inf'

            ELSE 'valeur_directe'
        END AS type_resultat

    FROM `project-3665c0d5-5952-473b-82e.hubeau_fact.fact_resultats`
)

SELECT
    code_parametre,

    COUNT(*) AS nb_resultats_total,

    COUNTIF(type_resultat = 'valeur_directe')
        AS nb_valeurs_directes,

    COUNTIF(type_resultat = 'censure_inf')
        AS nb_resultats_censures,

    COUNTIF(type_resultat = 'N.M.')
        AS nb_resultats_nm,

    SAFE_DIVIDE(
        COUNTIF(type_resultat = 'censure_inf'),
        COUNTIF(type_resultat != 'N.M.')
    ) AS part_resultats_censures

FROM typage_resultats

GROUP BY
    code_parametre

ORDER BY
    code_parametre;
