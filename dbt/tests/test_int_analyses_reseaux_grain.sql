-- Ce test vérifie le grain métier de int_analyses_reseaux :
-- une combinaison reference_analyse × code_reseau
-- ne doit apparaître qu'une seule fois.

select
    reference_analyse,
    code_reseau,
    count(*) as nombre_lignes

from {{ ref('int_analyses_reseaux') }}

group by
    reference_analyse,
    code_reseau

having count(*) > 1