with bornes_dates as (

    -- Détermine la période couverte par la dimension calendrier
    -- à partir du premier et du dernier prélèvement disponibles.
    select
        min(date_prelevement) as date_min,
        max(date_prelevement) as date_max

    from {{ ref('int_prelevements') }}

),

calendrier as (

    -- Génère toutes les dates comprises entre les deux bornes.
    -- Les jours sans prélèvement sont volontairement conservés
    -- afin d'obtenir un calendrier continu pour les futures analyses.
    select
        date_calendaire

    from bornes_dates
    cross join unnest(
        generate_date_array(date_min, date_max)
    ) as date_calendaire

),

dimension_date as (

    -- Grain cible :
    -- 1 ligne = 1 date calendaire comprise entre le premier et le dernier prélèvement disponibles.
    select
        date_calendaire as date,

        -- Attributs calendaires numériques.
        extract(year from date_calendaire) as annee,
        extract(quarter from date_calendaire) as trimestre,
        extract(month from date_calendaire) as numero_mois,

        -- Libellé du mois en français pour faciliter
        -- l'utilisation directe dans les tableaux de bord.
        case extract(month from date_calendaire)
            when 1 then 'Janvier'
            when 2 then 'Février'
            when 3 then 'Mars'
            when 4 then 'Avril'
            when 5 then 'Mai'
            when 6 then 'Juin'
            when 7 then 'Juillet'
            when 8 then 'Août'
            when 9 then 'Septembre'
            when 10 then 'Octobre'
            when 11 then 'Novembre'
            when 12 then 'Décembre'
        end as nom_mois,

        -- Identifiant de période au format YYYY-MM,
        -- utile pour le tri chronologique des analyses mensuelles.
        format_date('%Y-%m', date_calendaire) as annee_mois,

        extract(day from date_calendaire) as jour_mois,

        -- BigQuery utilise la convention suivante :
        -- dimanche = 1, lundi = 2, ..., samedi = 7.
        extract(dayofweek from date_calendaire) as jour_semaine,

        -- Libellé du jour de la semaine en français.
        case extract(dayofweek from date_calendaire)
            when 1 then 'Dimanche'
            when 2 then 'Lundi'
            when 3 then 'Mardi'
            when 4 then 'Mercredi'
            when 5 then 'Jeudi'
            when 6 then 'Vendredi'
            when 7 then 'Samedi'
        end as nom_jour_semaine

    from calendrier

)

select *
from dimension_date