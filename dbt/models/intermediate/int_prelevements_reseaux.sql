-- Grain cible :
-- 1 ligne = 1 association entre un prélèvement et un réseau.
--
-- Sur le périmètre étudié, les différents résultats d'un même prélèvement
-- présentent la même configuration de codes réseau.
--
-- Le nom du réseau n'est pas conservé dans ce modèle intermédiaire car
-- plusieurs libellés peuvent être associés à un même code_reseau.
-- Le champ debit n'est pas utilisé car il n'est pas interprété comme
-- un poids de répartition exploitable.

with source as (

    select *
    from {{ ref('stg_resultats_dis') }}

),

prelevements_reseaux as (

    select distinct
        code_prelevement,
        reseau.code as code_reseau

    from source,
    unnest(reseaux) as reseau

    where reseau.code is not null

)

select *
from prelevements_reseaux