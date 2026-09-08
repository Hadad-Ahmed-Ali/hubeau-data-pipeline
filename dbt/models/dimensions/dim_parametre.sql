-- Grain cible :
-- 1 ligne = 1 paramètre de qualité de l'eau
-- identifié par code_parametre.

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
    -- Les attributs descriptifs et l'unité ont été vérifiés comme stables
    -- pour un même code_parametre sur le périmètre étudié.
    --
    -- Certaines observations peuvent avoir un code_parametre_cas NULL.
    -- Lorsqu'un code CAS existe pour un paramètre, une seule valeur non nulle
    -- distincte a été observée ; MAX permet donc de conserver cette valeur.
    select
        code_parametre,

        any_value(code_parametre_se) as code_parametre_se,
        max(code_parametre_cas) as code_parametre_cas,
        any_value(code_type_parametre) as code_type_parametre,

        any_value(libelle_parametre) as libelle_parametre,
        any_value(libelle_parametre_maj) as libelle_parametre_maj,
        any_value(libelle_parametre_web) as libelle_parametre_web,

        any_value(code_unite) as code_unite,
        any_value(libelle_unite) as libelle_unite

    from source

    group by code_parametre

)

select *
from parametres