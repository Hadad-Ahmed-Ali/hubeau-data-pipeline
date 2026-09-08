with source as (

    -- Les prélèvements sont récupérés depuis l'ODS,
    -- où leur grain métier a déjà été établi et contrôlé.
    select
        code_prelevement,
        date_heure_prelevement,
        date_prelevement,
        code_commune,
        code_installation_amont,
        conclusion_conformite_prelevement,
        conformite_limites_bact_prelevement,
        conformite_limites_pc_prelevement,
        conformite_references_bact_prelevement,
        conformite_references_pc_prelevement

    from {{ ref('int_prelevements') }}

),

fact_prelevements as (

    -- Grain cible :
    -- 1 ligne = 1 prélèvement identifié par code_prelevement.
    --
    -- Les codes de commune et d'installation permettent de relier
    -- le fait aux dimensions géographique et installation.
    -- La date du prélèvement permet la relation avec dim_date.
    --
    -- Les indicateurs de conformité sont conservés au grain du prélèvement
    -- afin d'éviter leur duplication au niveau des résultats d'analyse.
    select
        code_prelevement,

        date_prelevement,
        date_heure_prelevement,

        code_commune,
        code_installation_amont,

        conclusion_conformite_prelevement,
        conformite_limites_bact_prelevement,
        conformite_limites_pc_prelevement,
        conformite_references_bact_prelevement,
        conformite_references_pc_prelevement

    from source

)

select *
from fact_prelevements