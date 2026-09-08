-- Vérifie le grain cible de fact_resultats :
-- 1 ligne = 1 résultat d'un paramètre donné,
-- pour un prélèvement donné et un lieu d'analyse donné.
--
-- Le test échoue si plusieurs lignes possèdent la même combinaison
-- code_prelevement + code_parametre + code_lieu_analyse.

select
    code_prelevement,
    code_parametre,
    code_lieu_analyse,
    count(*) as nb_lignes

from {{ ref('fact_resultats') }}

group by
    code_prelevement,
    code_parametre,
    code_lieu_analyse

having count(*) > 1