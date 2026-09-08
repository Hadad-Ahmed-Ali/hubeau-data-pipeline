-- Vérifie le grain cible de bridge_prelevements_reseaux :
-- 1 ligne = 1 association unique entre un prélèvement et un réseau.
--
-- Ni code_prelevement ni code_reseau ne sont uniques individuellement :
-- c'est leur combinaison qui doit être unique.

select
    code_prelevement,
    code_reseau,
    count(*) as nb_lignes

from {{ ref('bridge_prelevements_reseaux') }}

group by
    code_prelevement,
    code_reseau

having count(*) > 1