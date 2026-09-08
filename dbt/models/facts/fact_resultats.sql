with resultats as (

    -- Les résultats sont récupérés depuis l'ODS,
    -- où leur grain et les règles de qualité ont déjà été structurés.
    select
        code_prelevement,
        code_parametre,
        code_lieu_analyse,
        reference_analyse,

        resultat_alphanumerique,
        resultat_numerique,
        operateur_resultat,
        seuil_resultat,

        limite_qualite_parametre,
        operateur_min_limite_qualite,
        valeur_min_limite_qualite,
        operateur_max_limite_qualite,
        valeur_max_limite_qualite,
        unite_limite_qualite,

        reference_qualite_parametre,
        operateur_min_reference_qualite,
        valeur_min_reference_qualite,
        operateur_max_reference_qualite,
        valeur_max_reference_qualite,
        unite_reference_qualite

    from {{ ref('int_resultats') }}

),

prelevements as (

    -- Les attributs nécessaires aux axes d'analyse temporel,
    -- géographique et installation sont récupérés au grain du prélèvement.
    select
        code_prelevement,
        date_prelevement,
        date_heure_prelevement,
        code_commune,
        code_installation_amont

    from {{ ref('int_prelevements') }}

),

fact_resultats as (

    -- Grain cible :
    -- 1 ligne = 1 résultat d'un paramètre donné, pour un prélèvement donné et un lieu d'analyse donné.
    --
    -- Sur le périmètre étudié, la combinaison
    -- code_prelevement + code_parametre + code_lieu_analyse
    -- identifie un résultat sans doublon.
    --
    -- Les attributs du prélèvement sont ajoutés afin de permettre
    -- les relations avec les dimensions date, géographie et installation,
    -- sans modifier le grain du résultat.
    select
        r.code_prelevement,
        r.code_parametre,
        r.code_lieu_analyse,

        -- Information source : reference_analyse peut être NULL
        -- et ne constitue pas l'identifiant du résultat.
        r.reference_analyse,

        p.date_prelevement,
        p.date_heure_prelevement,
        p.code_commune,
        p.code_installation_amont,

        -- Représentation complète du résultat.
        -- resultat_numerique seul ne suffit pas à interpréter
        -- les valeurs censurées telles que "<0,10" ou les valeurs "N.M.".
        r.resultat_alphanumerique,
        r.resultat_numerique,
        r.operateur_resultat,
        r.seuil_resultat,

        -- Limite de qualité applicable au résultat lorsqu'elle existe.
        r.limite_qualite_parametre,
        r.operateur_min_limite_qualite,
        r.valeur_min_limite_qualite,
        r.operateur_max_limite_qualite,
        r.valeur_max_limite_qualite,
        r.unite_limite_qualite,

        -- Référence de qualité applicable au résultat lorsqu'elle existe.
        r.reference_qualite_parametre,
        r.operateur_min_reference_qualite,
        r.valeur_min_reference_qualite,
        r.operateur_max_reference_qualite,
        r.valeur_max_reference_qualite,
        r.unite_reference_qualite

    from resultats as r

    -- INNER JOIN volontaire :
    -- chaque résultat appartient à un prélèvement et int_prelevements
    -- contient une seule ligne par code_prelevement.
    --
    -- La relation est donc de type N:1 :
    -- plusieurs résultats peuvent appartenir à un même prélèvement.
    --
    -- Cette jointure ne doit ni dupliquer ni supprimer de résultats :
    -- fact_resultats doit conserver les 19 923 lignes de int_resultats.
    inner join prelevements as p
        on r.code_prelevement = p.code_prelevement

)

select *
from fact_resultats
