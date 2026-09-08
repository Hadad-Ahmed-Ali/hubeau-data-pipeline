-- Grain cible :
-- 1 ligne = 1 résultat d'un paramètre donné,
-- pour un prélèvement donné et un lieu d'analyse donné.
--
-- Sur le périmètre étudié, la combinaison
-- code_prelevement + code_parametre + code_lieu_analyse
-- identifie un résultat sans doublon.

with source as (

    select *
    from {{ ref('stg_resultats_dis') }}

),

resultats as (

    select

        -- --------------------------------------------------------------------
        -- Identification du résultat
        -- --------------------------------------------------------------------

        code_prelevement,
        code_parametre,
        code_lieu_analyse,

        -- reference_analyse est conservée comme information source.
        -- Elle peut être NULL et ne constitue pas l'identifiant du résultat.
        reference_analyse,

        -- --------------------------------------------------------------------
        -- Paramètre
        -- --------------------------------------------------------------------

        code_parametre_se,
        code_parametre_cas,
        code_type_parametre,
        libelle_parametre,
        libelle_parametre_maj,
        libelle_parametre_web,

        -- --------------------------------------------------------------------
        -- Résultat source
        -- --------------------------------------------------------------------

        -- Les représentations alphanumérique et numérique sont toutes les
        -- deux conservées. La première porte notamment l'information de
        -- censure (<0,5...), tandis que la seconde peut être NULL pour N.M.
        resultat_alphanumerique,
        resultat_numerique,

        -- Opérateur associé à un résultat censuré.
        regexp_extract(
            trim(resultat_alphanumerique),
            r'^(<=|>=|<|>)'
        ) as operateur_resultat,

        -- Seuil numérique associé à un résultat censuré.
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

        -- --------------------------------------------------------------------
        -- Unité du résultat
        -- --------------------------------------------------------------------

        code_unite,
        libelle_unite,

        -- --------------------------------------------------------------------
        -- Expressions qualité source
        -- --------------------------------------------------------------------

        -- Limite et référence restent séparées car elles représentent
        -- deux notions différentes dans les données Hub'Eau.
        limite_qualite_parametre,
        reference_qualite_parametre

    from source

),

qualite_structuree as (

    select
        *,

        -- --------------------------------------------------------------------
        -- Limite de qualité : borne minimale
        -- --------------------------------------------------------------------

        case
            when regexp_contains(
                trim(limite_qualite_parametre),
                r'^>='
            )
            then '>='
            when regexp_contains(
                trim(limite_qualite_parametre),
                r'^>'
            )
            then '>'
        end as operateur_min_limite_qualite,

        safe_cast(
            replace(
                regexp_extract(
                    trim(limite_qualite_parametre),
                    r'^(?:>=|>)\s*([0-9]+(?:[.,][0-9]+)?)'
                ),
                ',',
                '.'
            )
            as float64
        ) as valeur_min_limite_qualite,

        -- --------------------------------------------------------------------
        -- Limite de qualité : borne maximale
        -- --------------------------------------------------------------------

        -- Le groupe (?:<=|<) est volontairement non capturant afin de
        -- conserver l'expression complète, par exemple "<=50".
        regexp_extract(
            trim(limite_qualite_parametre),
            r'(?:<=|<)\s*[0-9]+(?:[.,][0-9]+)?'
        ) as expression_max_limite_qualite,

        -- --------------------------------------------------------------------
        -- Référence de qualité : borne minimale
        -- --------------------------------------------------------------------

        case
            when regexp_contains(
                trim(reference_qualite_parametre),
                r'^>='
            )
            then '>='
            when regexp_contains(
                trim(reference_qualite_parametre),
                r'^>'
            )
            then '>'
        end as operateur_min_reference_qualite,

        safe_cast(
            replace(
                regexp_extract(
                    trim(reference_qualite_parametre),
                    r'^(?:>=|>)\s*([0-9]+(?:[.,][0-9]+)?)'
                ),
                ',',
                '.'
            )
            as float64
        ) as valeur_min_reference_qualite,

        -- La borne maximale peut apparaître au début de l'expression
        -- ("<=25 °C") ou après une borne minimale
        -- (">=6,5 et <=9 unité pH").
        --
        -- Le groupe est non capturant afin de récupérer l'expression
        -- complète, par exemple "<=9".
        regexp_extract(
            trim(reference_qualite_parametre),
            r'(?:<=|<)\s*[0-9]+(?:[.,][0-9]+)?'
        ) as expression_max_reference_qualite

    from resultats

),

final as (

    select

        -- --------------------------------------------------------------------
        -- Identification
        -- --------------------------------------------------------------------

        code_prelevement,
        code_parametre,
        code_lieu_analyse,
        reference_analyse,

        -- --------------------------------------------------------------------
        -- Paramètre
        -- --------------------------------------------------------------------

        code_parametre_se,
        code_parametre_cas,
        code_type_parametre,
        libelle_parametre,
        libelle_parametre_maj,
        libelle_parametre_web,

        -- --------------------------------------------------------------------
        -- Résultat
        -- --------------------------------------------------------------------

        resultat_alphanumerique,
        resultat_numerique,
        operateur_resultat,
        seuil_resultat,

        code_unite,
        libelle_unite,

        -- --------------------------------------------------------------------
        -- Qualité source
        -- --------------------------------------------------------------------

        limite_qualite_parametre,
        reference_qualite_parametre,

        -- --------------------------------------------------------------------
        -- Limite de qualité structurée
        -- --------------------------------------------------------------------

        operateur_min_limite_qualite,
        valeur_min_limite_qualite,

        regexp_extract(
            expression_max_limite_qualite,
            r'^(<=|<)'
        ) as operateur_max_limite_qualite,

        safe_cast(
            replace(
                regexp_extract(
                    expression_max_limite_qualite,
                    r'^(?:<=|<)\s*([0-9]+(?:[.,][0-9]+)?)'
                ),
                ',',
                '.'
            )
            as float64
        ) as valeur_max_limite_qualite,

        -- L'unité est celle du résultat. Les unités ont été vérifiées comme
        -- stables par paramètre sur le périmètre étudié.
        case
            when nullif(trim(limite_qualite_parametre), '') is not null
            then libelle_unite
        end as unite_limite_qualite,

        -- --------------------------------------------------------------------
        -- Référence de qualité structurée
        -- --------------------------------------------------------------------

        operateur_min_reference_qualite,
        valeur_min_reference_qualite,

        regexp_extract(
            expression_max_reference_qualite,
            r'^(<=|<)'
        ) as operateur_max_reference_qualite,

        safe_cast(
            replace(
                regexp_extract(
                    expression_max_reference_qualite,
                    r'^(?:<=|<)\s*([0-9]+(?:[.,][0-9]+)?)'
                ),
                ',',
                '.'
            )
            as float64
        ) as valeur_max_reference_qualite,

        case
            when nullif(trim(reference_qualite_parametre), '') is not null
            then libelle_unite
        end as unite_reference_qualite

    from qualite_structuree

)

select *
from final