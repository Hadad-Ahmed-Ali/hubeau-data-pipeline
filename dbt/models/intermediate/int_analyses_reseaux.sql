with source as (

    select *
    from {{ ref('stg_resultats_dis') }}

),

reseaux_exploses as (

    -- UNNEST transforme le tableau de réseaux en lignes individuelles.
    -- À ce stade, plusieurs lignes peuvent encore exister pour une même
    -- association analyse × réseau, notamment lorsque plusieurs variantes
    -- de nom sont présentes pour un même code_reseau.
    select
        reference_analyse,
        code_prelevement,
        reseau.code as code_reseau,
        nullif(trim(reseau.nom), '') as nom_reseau,
        nullif(trim(reseau.debit), '') as debit_reseau

    from source
    cross join unnest(reseaux) as reseau

),

analyses_reseaux as (

    -- Grain cible : une ligne représente une association entre une analyse et un réseau.
    -- C'est-à-dire : 1 ligne = 1 association entre reference_analyse et code_reseau.

    -- Schéma conceptuel :

    -- STG on a :
    -- 1 analyse
    -- └── reseaux ARRAY
    --     ├── réseau A / nom variante 1
    --     ├── réseau A / nom variante 2
    --     ├── réseau A / nom variante 3
    --     └── réseau B
    --
    -- Après UNNEST + regroupement, on obtient :
    --
    -- int_analyses_reseaux
    -- ├── analyse × réseau A → [noms 1, 2, 3]
    -- └── analyse × réseau B → [nom ...]

    select
        reference_analyse,
        code_reseau,

        -- code_prelevement est conservé pour permettre de relier facilement
        -- l'association réseau au prélèvement correspondant.
        any_value(code_prelevement) as code_prelevement,

        -- Un même code_reseau peut être associé à plusieurs variantes de nom.
        -- Elles sont conservées dans un ARRAY plutôt que de choisir
        -- arbitrairement un seul libellé.
        array_agg(
            distinct nom_reseau ignore nulls
            order by nom_reseau
        ) as noms_reseau,

        -- L'exploration a montré qu'une association analyse × réseau
        -- ne possède pas plusieurs débits non vides dans les données actuelles.
        -- Le débit reste ici un attribut de la relation et non du réseau,
        -- car il peut évoluer entre différentes analyses.
        any_value(debit_reseau) as debit_reseau

    from reseaux_exploses

    where code_reseau is not null

    group by
        reference_analyse,
        code_reseau

)

select *
from analyses_reseaux