with source as (

    -- Les informations géographiques sont récupérées depuis l'ODS,
    -- où elles sont déjà associées au grain du prélèvement.
    select
        code_commune,
        nom_commune,
        code_departement,
        nom_departement

    from {{ ref('int_prelevements') }}

),

geographies as (

    -- Grain cible :
    -- 1 ligne = 1 commune identifiée par code_commune.
    --
    -- Les attributs géographiques ont été vérifiés en amont :
    -- dans les données actuelles, un code_commune est associé
    -- à un seul nom de commune et à un seul département.
    select distinct
        code_commune,
        nom_commune,
        code_departement,
        nom_departement

    from source

)

select *
from geographies