with source as (

    -- Les informations décrivant les réseaux sont récupérées depuis
    -- le champ ARRAY reseaux du modèle de staging.
    --
    -- Le modèle int_prelevements_reseaux conserve volontairement
    -- uniquement les associations prélèvement × réseau et ne porte
    -- pas les attributs descriptifs du réseau.
    select
        reseaux

    from {{ ref('stg_resultats_dis') }}

),

reseaux_exploses as (

    -- Déplie le tableau reseaux afin d'obtenir une ligne
    -- par occurrence de réseau observée dans les résultats.
    select
        reseau.code as code_reseau,
        reseau.nom as nom_reseau

    from source
    cross join unnest(reseaux) as reseau

    where reseau.code is not null

),

reseaux as (

    -- Grain cible :
    -- 1 ligne = 1 réseau identifié par code_reseau.
    --
    -- Plusieurs variantes de nom peuvent être observées pour un même réseau.
    -- Aucune variante n'est choisie arbitrairement comme libellé principal :
    -- toutes les valeurs distinctes non nulles sont conservées.
    select
        code_reseau,

        array_agg(
            distinct nom_reseau
            ignore nulls
            order by nom_reseau
        ) as noms_reseau

    from reseaux_exploses

    group by code_reseau

)

select *
from reseaux