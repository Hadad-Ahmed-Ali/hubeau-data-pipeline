-- Ce test vérifie le grain métier de int_prelevements_reseaux :
-- une combinaison code_prelevement × code_reseau
-- ne doit apparaître qu'une seule fois.
--
-- Ce grain a été validé sur le périmètre étudié
-- et ne constitue pas une règle universelle de l'API Hub'Eau.

select
    code_prelevement,
    code_reseau,
    count(*) as nombre_lignes

from {{ ref('int_prelevements_reseaux') }}

group by
    code_prelevement,
    code_reseau

having count(*) > 1