with source as (

    -- Les réseaux sont récupérés depuis le modèle intermédiaire
    -- représentant les associations entre analyses et réseaux.
    -- noms_reseau contient les différentes variantes de libellé
    -- observées pour une association analyse × réseau.
    select
        code_reseau,
        noms_reseau

    from {{ ref('int_analyses_reseaux') }}

),

noms_reseaux_exploses as (

    -- Cheminement de la transformation :
    --
    -- int_analyses_reseaux
    -- 1 ligne = 1 association analyse × réseau
    --              │
    --              │ noms_reseau ARRAY
    --              ▼
    --            UNNEST
    --              │
    --              ▼
    -- 1 ligne = 1 réseau × 1 variante de nom
    --              │
    --              ▼
    --     GROUP BY code_reseau
    --              │
    --              ▼
    -- dim_reseau
    -- 1 ligne = 1 réseau avec l'ensemble
    --             de ses variantes de nom
    --
    -- L'UNNEST permet donc ici de déplier les tableaux de noms
    -- avant de les consolider à l'échelle de chaque réseau.
    select
        code_reseau,
        nom_reseau

    from source
    cross join unnest(noms_reseau) as nom_reseau

),

reseaux as (

    -- Grain cible :
    -- 1 ligne = 1 réseau identifié par code_reseau.
    --
    -- L'exploration a montré que plusieurs variantes de nom peuvent
    -- coexister pour un même code_reseau sur une même période.
    -- Contrairement aux installations, il ne s'agit donc pas simplement
    -- d'une évolution chronologique du libellé.
    --
    -- Aucun libellé n'est choisi arbitrairement comme nom principal :
    -- toutes les variantes distinctes observées sont conservées.
    select
        code_reseau,

        array_agg(
            distinct nom_reseau
            order by nom_reseau
        ) as noms_reseau

    from noms_reseaux_exploses

    where code_reseau is not null

    group by code_reseau

)

select *
from reseaux