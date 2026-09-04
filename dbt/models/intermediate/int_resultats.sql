with source as (

    select *
    from {{ ref('stg_resultats_dis') }}

),

resultats as (

    -- Grain cible : une ligne représente le résultat d'analyse d'un paramètre donné pour un prélèvement.
    -- c'est à dire : 1 ligne = 1 résultat d'analyse d'un paramètre
    select

        -- Identifiants permettant de relier le résultat
        -- au prélèvement et à la référence d'analyse.
        code_prelevement,
        reference_analyse,

        -- Informations décrivant le paramètre analysé.
        code_parametre,
        code_parametre_se,
        code_parametre_cas,
        code_type_parametre,
        libelle_parametre,
        libelle_parametre_maj,
        libelle_parametre_web,

        -- Valeurs source fournies par Hub'Eau.
        -- Les deux représentations sont conservées afin de ne perdre
        -- aucune information, notamment pour les résultats censurés.
        resultat_alphanumerique,
        resultat_numerique,

        -- Extraction de l'opérateur lorsque le résultat est exprimé
        -- sous une forme telle que "<0,5" ou "<=1".
        regexp_extract(
            trim(resultat_alphanumerique),
            r'^(<=|>=|<|>)'
        ) as operateur_resultat,

        -- Extraction du seuil associé aux résultats censurés
        -- (ex. "<0,5" → 0.5).
        -- SAFE_CAST est utilisé volontairement : si Hub'Eau fournit un format
        -- inattendu, la valeur dérivée devient NULL au lieu de faire échouer le modèle.
        safe_cast(
            replace(
                regexp_extract(
                    trim(resultat_alphanumerique),
                    r'^(?:<=|>=|<|>)\s*([0-9]+(?:[.,][0-9]+)?)'
                ),
                ',',
                '.'
            )
            as float64
        ) as seuil_resultat,

        -- Unité associée au résultat.
        code_unite,
        libelle_unite,

        -- Valeurs source décrivant les limites et références
        -- de qualité associées au paramètre.
        limite_qualite_parametre,
        reference_qualite_parametre,

        -- Extraction de l'opérateur de la limite de qualité
        -- (ex. "<=50 mg/L" → "<=").
        regexp_extract(
            trim(limite_qualite_parametre),
            r'^(<=|>=|<|>)'
        ) as operateur_limite_qualite,

        -- Extraction de la valeur numérique de la limite de qualité
        -- (ex. "<=50 mg/L" → 50.0).
        -- SAFE_CAST protège également le pipeline contre un éventuel format
        -- source non reconnu en retournant NULL plutôt qu'une erreur.
        safe_cast(
            replace(
                regexp_extract(
                    trim(limite_qualite_parametre),
                    r'^(?:<=|>=|<|>)\s*([0-9]+(?:[.,][0-9]+)?)'
                ),
                ',',
                '.'
            )
            as float64
        ) as numerique_limite_qualite,

        -- Extraction de l'unité présente dans la limite de qualité
        -- (ex. "<=50 mg/L" → "mg/L").
        nullif(
            trim(
                regexp_extract(
                    trim(limite_qualite_parametre),
                    r'^(?:<=|>=|<|>)\s*[0-9]+(?:[.,][0-9]+)?\s*(.*)$'
                )
            ),
            ''
        ) as unite_limite_qualite

    from source

)

select *
from resultats