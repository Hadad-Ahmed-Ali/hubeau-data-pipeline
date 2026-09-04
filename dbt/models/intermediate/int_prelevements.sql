with source as (

    select *
    from {{ ref('stg_resultats_dis') }}

),

prelevements as (

    select

    --- Le modèle doit garantir une seule ligne par prélèvement : grain cible = 1 ligne par code_prelevement, autrement dit 1 ligne = 1 prélèvement
    --- Les attributs ci-dessous ont été vérifiés comme cohérents
    --- pour un même code_prelevement dans les données actuelles.

        code_prelevement,

        -- On conserve le timestamp source et on ajoute des attributs calendaires
        -- afin de faciliter les analyses temporelles dans les couches suivantes.
        any_value(date_prelevement) as date_heure_prelevement,
        date(any_value(date_prelevement)) as date_prelevement,
        extract(year from any_value(date_prelevement)) as annee_prelevement,
        extract(month from any_value(date_prelevement)) as mois_prelevement,
        extract(day from any_value(date_prelevement)) as jour_prelevement,

        -- Informations géographiques associées au prélèvement.
        any_value(code_commune) as code_commune,
        any_value(nom_commune) as nom_commune,

        -- Contexte de l'analyse et de l'installation amont.
        any_value(code_lieu_analyse) as code_lieu_analyse,
        any_value(code_installation_amont) as code_installation_amont,
        any_value(nom_installation_amont) as nom_installation_amont,

        -- Acteurs associés au prélèvement.
        -- Ces noms sont conservés comme attributs descriptifs et non comme identifiants stables.
        any_value(nom_uge) as nom_uge,
        any_value(nom_distributeur) as nom_distributeur,
        any_value(nom_moa) as nom_moa,

        -- La conformité concerne le prélèvement dans son ensemble,
        -- et non un résultat de paramètre particulier.
        any_value(conclusion_conformite_prelevement)
            as conclusion_conformite_prelevement,

        any_value(conformite_limites_bact_prelevement)
            as conformite_limites_bact_prelevement,

        any_value(conformite_limites_pc_prelevement)
            as conformite_limites_pc_prelevement,

        any_value(conformite_references_bact_prelevement)
            as conformite_references_bact_prelevement,

        any_value(conformite_references_pc_prelevement)
            as conformite_references_pc_prelevement

    from source
    group by code_prelevement

)

select *
from prelevements