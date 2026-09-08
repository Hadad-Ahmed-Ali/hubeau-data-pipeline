-- Grain cible :
-- 1 ligne = 1 résultat brut retourné par l'API Hub'Eau.
--
-- La couche STG préserve le grain et les 32 champs du RAW.
-- Les interprétations métier et l'éclatement du champ reseaux
-- sont volontairement reportés à la couche ODS.

with source as (

    select *
    from {{ source('hubeau_raw', 'resultats_dis_raw') }}

),

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