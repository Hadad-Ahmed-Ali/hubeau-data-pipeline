with source as (
--- Ici je selectionne toutes les colonnes de la données sources, par la suite certains pourront ne pas etre prise selectionner dans le stg
--- si par exemple une nouvelle colonne est rajoutée elle sera accessible dans source, mais elle n'entrera pas automatiquement dans le résultat final de STG.
    select *
    from {{ source('hubeau_raw', 'resultats_dis_raw') }}

),

--- On selectionne les 32 colonnes explicitement sélectionnées, mêmes types, mêmes noms, grain préservé,
--- NULL préservés, résultat alpha + numérique préservés, reseaux reste ARRAY<STRUCT>
staged as (

    select

        -- Géographie
        code_departement,
        nom_departement,
        code_commune,
        nom_commune,

        -- Prélèvement / analyse
        code_prelevement,
        reference_analyse,
        date_prelevement,
        code_lieu_analyse,

        -- Paramètre
        code_parametre,
        code_parametre_se,
        code_parametre_cas,
        libelle_parametre,
        libelle_parametre_maj,
        libelle_parametre_web,
        code_type_parametre,

        -- Résultat / unité
        resultat_alphanumerique,
        resultat_numerique,
        code_unite,
        libelle_unite,

        -- Limites / références qualité
        limite_qualite_parametre,
        reference_qualite_parametre,

        -- Conformité du prélèvement
        conclusion_conformite_prelevement,
        conformite_limites_bact_prelevement,
        conformite_limites_pc_prelevement,
        conformite_references_bact_prelevement,
        conformite_references_pc_prelevement,

        -- Acteurs / installation
        nom_uge,
        nom_distributeur,
        nom_moa,
        code_installation_amont,
        nom_installation_amont,

        -- Réseaux
        reseaux

    from source

)

select *
from staged