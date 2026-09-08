-- Ce test vérifie le grain métier de int_resultats :
-- une combinaison code_prelevement × code_parametre × code_lieu_analyse
-- ne doit apparaître qu'une seule fois.
--
-- Cette combinaison a été validée sur le périmètre étudié
-- et ne constitue pas une règle universelle de l'API Hub'Eau.

select
    code_prelevement,
    code_parametre,
    code_lieu_analyse,
    count(*) as nombre_lignes

from {{ ref('int_resultats') }}

group by
    code_prelevement,
    code_parametre,
    code_lieu_analyse

having count(*) > 1