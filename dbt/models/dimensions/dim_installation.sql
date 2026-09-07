with source as (

    -- Les installations sont récupérées depuis les prélèvements,
    -- où chaque prélèvement est associé à son installation amont
    -- et au libellé observé à la date du prélèvement.
    select
        code_installation_amont,
        nom_installation_amont,
        date_prelevement

    from {{ ref('int_prelevements') }}

),

installations as (

    -- Grain cible :
    -- 1 ligne = 1 installation amont identifiée
    -- par code_installation_amont.
    --
    -- L'exploration a montré qu'un même code d'installation peut
    -- conserver son identité tout en changeant de libellé dans le temps.
    -- Le libellé associé au prélèvement le plus récent est donc retenu
    -- comme libellé courant de l'installation.
    select
        code_installation_amont,

        array_agg(
            nom_installation_amont
            ignore nulls
            order by date_prelevement desc
            limit 1
        )[safe_offset(0)] as nom_installation_amont

    from source

    where code_installation_amont is not null

    group by code_installation_amont

)

select *
from installations