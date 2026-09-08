with source as (

    -- Les associations prélèvement × réseau sont récupérées depuis l'ODS,
    -- où leur grain a déjà été établi et contrôlé.
    select
        code_prelevement,
        code_reseau

    from {{ ref('int_prelevements_reseaux') }}

),

bridge_prelevements_reseaux as (

    -- Grain cible :
    -- 1 ligne = 1 association unique entre un prélèvement et un réseau.
    --
    -- Rôle du modèle :
    -- cette table fait littéralement le pont entre fact_prelevements
    -- et dim_reseau afin de représenter leur relation plusieurs-à-plusieurs
    -- sans dupliquer les lignes de la table de faits.
    --
    -- Relation dans le modèle analytique :
    --
    -- fact_prelevements
    --        |
    --        | 1:N
    --        v
    -- bridge_prelevements_reseaux
    --        |
    --        | N:1
    --        v
    --    dim_reseau
    --
    -- Un prélèvement peut être associé à plusieurs réseaux et un même
    -- réseau peut être associé à plusieurs prélèvements.
    select
        code_prelevement,
        code_reseau

    from source

)

select *
from bridge_prelevements_reseaux