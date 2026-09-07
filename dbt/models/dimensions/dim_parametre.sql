with source as (

    -- Les informations décrivant les paramètres sont récupérées
    -- depuis le modèle intermédiaire des résultats.
    select
        code_parametre,
        code_parametre_se,
        code_parametre_cas,
        code_type_parametre,
        libelle_parametre,
        libelle_parametre_maj,
        libelle_parametre_web,
        code_unite,
        libelle_unite

    from {{ ref('int_resultats') }}

),

parametres as (

    -- Grain cible :
    -- 1 ligne = 1 paramètre de qualité de l'eau
    -- identifié par code_parametre.
    --
    -- Les attributs ont été vérifiés comme stables dans les données actuelles.
    -- Pour code_parametre_cas, certaines lignes sont NULL alors qu'une unique
    -- valeur non nulle existe ; on conserve donc cette valeur lorsqu'elle existe.
    select
        code_parametre,

        any_value(code_parametre_se) as code_parametre_se,

        array_agg(
            distinct code_parametre_cas ignore nulls
            limit 1
        )[safe_offset(0)] as code_parametre_cas,

        any_value(code_type_parametre) as code_type_parametre,
        any_value(libelle_parametre) as libelle_parametre,
        any_value(libelle_parametre_maj) as libelle_parametre_maj,

        array_agg(
            distinct libelle_parametre_web ignore nulls
            limit 1
        )[safe_offset(0)] as libelle_parametre_web,

        any_value(code_unite) as code_unite,
        any_value(libelle_unite) as libelle_unite

    from source

    group by code_parametre

)

select *
from parametres