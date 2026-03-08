/*
===========================
Database Schema - !!!! USING SNOWFLAKE
===========================

TABLE 1: teams
Description: Reference table for all NFL franchises.
- team_id: (INT, Primary Key) Unique identifier for each team.
- team_name: (TEXT) Full name (e.g., 'Green Bay Packers').
- conference: (TEXT) AFC or NFC.
- division: (TEXT) Specific grouping (e.g., 'North', 'West').

TABLE 2: dstadiums
Description: Geographic and structural data for every NFL venue.
- stadium_id: (INT, Primary Key) Unique identifier for each stadium.
- venue_name: (TEXT) Official name of the stadium.
- venue_city: (TEXT) City location.
- venue_state: (TEXT) State abbreviation.
- lat/lon: (FLOAT) GPS coordinates for geographic travel analysis.
- indoor: (BOOLEAN) 1 = Dome/Retractable, 0 = Outdoor.

TABLE 3: games
Description: The core transaction table containing every game's result.
- game_id: (INT, Primary Key) Unique identifier for a specific matchup.
- date: (DATE) The day the game was played.
- season: (INT) Year of the season (e.g., 2023).
- week: (TEXT) Week number or Playoff round.
- home_team_id: (INT, FK) Link to teams (team_id).
- away_team_id: (INT, FK) Link to teams (team_id).
- stadium_id: (INT, FK) Link to stadiums (stadium_id).
- home_score/away_score: (INT) Points scored by each team.
- total_points: (INT) Sum of scores (Target variable for regression).

TABLE 4: weather
Description: Environmental conditions captured at kickoff for every game.
- game_id: (INT, Foreign Key) Link to games.
- avg_temp: (FLOAT) Temperature in Fahrenheit.
- wind_speed_avg: (FLOAT) Wind speed in MPH.
- rain_any: (BOOLEAN) 1 = Any rainfall during game, 0 = Dry.
- snow_any: (BOOLEAN) 1 = Any snowfall during game, 0 = None.

TABLE 5: betting_data
Description: The Vegas market layer for comparing predictions vs reality.
- schedule_date: (DATE) Matchup date.
- team_favorite_id: (TEXT) Abbreviation of the team Vegas expects to win.
- spread_favorite: (FLOAT) The point spread (e.g., -7 means fav must win by 7+).
- over_under_line: (FLOAT) The total points predicted by the market.
*/

-- SQL QUERIES ------------------------------------------------------

-- 1. Total points average per season
--    > Finding average of total points per game per season
/*
Features:
- GROUP BY, Aggregate function
*/

SELECT season, AVG(total_points)
FROM FINAL_PROJECT.PUBLIC.GAMES
GROUP BY season
ORDER BY season

-- 2. Average total point indoor vs outdoor
--    > Finding the average to total points of outdoor games vs indoor games
/*
Features:
- GROUP BY, Aggregate function
- JOIN
*/

SELECT s.indoor, AVG(g.total_points)
FROM FINAL_PROJECT.PUBLIC.GAMES g
LEFT JOIN FINAL_PROJECT.PUBLIC.STADIUMS s ON s.stadium_id = g.stadium_id -- join with stadium tables that contains the information of indoor/outdoor stadium
GROUP BY s.indoor

-- 3. Average home score vs away score each season
--    > Figuring out the home leverage by finding the average points of home score vs away score
/*
Features:
- GROUP BY, Aggregate function
*/

SELECT
    season,
    AVG(home_score),
    AVG(away_score)
FROM FINAL_PROJECT.PUBLIC.GAMES
GROUP BY season
ORDER BY season

-- 4. Wind speed effect to total points
--    > Finding the effect of wind speed to the average total points scored per games
/*
Features:
- GROUP BY, Aggregate function
- CASE WHEN
- SUBQUERY
- JOIN
*/

SELECT
    CASE
        WHEN wind_speed_avg < lower THEN 'low_speed'
        WHEN wind_speed_avg < upper THEN 'med_speed'
        ELSE 'high_speed'
    END wind_speed_classification, -- classification of windspeed into 3 different classes
    AVG(total_points)
FROM (
    SELECT
        g.game_id,
        g.total_points,
        w.wind_speed_avg,
        (MIN(w.wind_speed_avg) OVER () + (MAX(w.wind_speed_avg) OVER () - MIN(w.wind_speed_avg) OVER ())/3) lower, -- divide the groups into 3, finding the cutoff line by using max-min/3 interval
        MIN(w.wind_speed_avg) OVER () + 2*(MAX(w.wind_speed_avg) OVER () - MIN(w.wind_speed_avg) OVER ())/3 upper
    FROM FINAL_PROJECT.PUBLIC.GAMES g
    LEFT JOIN FINAL_PROJECT.PUBLIC.WEATHER w ON w.game_id = g.game_id
    ) a
GROUP BY 1 -- group by highspeed (using number (order of select) for ease of use and quickness)
ORDER BY 2 DESC -- order by avg total points

-- 5. Average total points raining vs not raining 
--    > Finding if rain has any effect on the total points score per games
/*
Features:
- GROUP BY, Aggregate function
- JOIN
*/

SELECT
    g.season,
    w.rain_any,
    AVG(g.total_points)
FROM FINAL_PROJECT.PUBLIC.GAMES g
LEFT JOIN FINAL_PROJECT.PUBLIC.WEATHER w ON w.game_id = g.game_id
GROUP BY g.season, w.rain_any
ORDER BY g.season, w.rain_any

-- 6. Teams with most wins per season
--    > calculating total wins for each team per season (subquery), and then finding the team with the most wins per season
/*
Features:
- GROUP BY, Aggregate function
- SUBQUERY
- CASE WHEN
- WINDOW FUNCTION (rank over partition by)
- JOIN
*/

SELECT
    b.season,
    t.team_name,
    b.total_wins
FROM (
    SELECT
        season,
        team_id,
        total_wins,
        RANK() OVER (PARTITION BY season ORDER BY total_wins DESC) rnk
    FROM (
        SELECT
            season,
            CASE
                WHEN home_score > away_score THEN home_team_id
                WHEN away_score > home_score THEN away_team_id
                ELSE NULL END team_id, -- showing the winning team id only
            COUNT(*) total_wins -- calculating the count as total wins immediately in single query
        FROM FINAL_PROJECT.PUBLIC.GAMES
        GROUP BY season, team_id
        ) a
    ) b
LEFT JOIN FINAL_PROJECT.PUBLIC.TEAMS t ON t.team_id = b.team_id
WHERE
    rnk = 1 -- select only rank 1 teams from the window function select rnk -> order by total wins from subquery
ORDER BY 1

-- 7. Average error of the official over_under_line from the actual score 
--    > Finding insights from the betting data, finding the average error of vegas line
/*
Features:
- GROUP BY, Aggregate function
*/

SELECT 
    season,
    ROUND(AVG(over_under_line), 2) AS avg_line, -- use round to simplify the decimal points
    ROUND(AVG(home_score + away_score), 2) AS avg_actual_total,
    ROUND(AVG(ABS((home_score + away_score) - over_under_line)), 2) AS avg_error -- average of the error/discrepancy of vegas line
FROM FINAL_PROJECT.PUBLIC.BETTING_DATA
GROUP BY season
ORDER BY season

-- 8. Percentage of underdog home team wins
--    > Finding the percentage of underdog home team who wins -> homedog win percentage
/*
Features:
- GROUP BY, Aggregate function
- CASE WHEN
*/

SELECT 
    season,
    COUNT(*) AS underdog_home_games, -- count of all underdog home games
    SUM(CASE WHEN home_score > away_score THEN 1 ELSE 0 END) AS home_dog_wins, -- sum only if the home team wins (homedog)
    AVG(CASE WHEN home_score > away_score THEN 1 ELSE 0 END) AS win_pct -- average of home dog wins from all underdog home games (using case when)
FROM
    FINAL_PROJECT.PUBLIC.BETTING_DATA
WHERE
    team_favorite_id != home_team -- main filtering of underdog home team games
GROUP BY season
ORDER BY season

-- 9. PPG last 10 games for each team
--    > finding the points per game (last 10 matches) for each team, to be used in the regression analysis
/*
Features:
- GROUP BY, Aggregate function
- UNION
- SUBQUERY
- WINDOW FUNCTION
- SUBQUERY
- JOIN
*/

SELECT
    a.game_id,
    a.team_id,
    t.team_name,
    a.score,
    AVG(a.score) OVER (PARTITION BY a.team_id ORDER BY a.date ROWS BETWEEN 10 PRECEDING AND 1 PRECEDING) avg_ppg_10
    -- finding average of each team (partition by) with a windows function from rows -10 to rows -1 (last 10 matches ordered by date)
FROM (
    SELECT
        game_id,
        date,
        home_team_id team_id,
        home_score score
    FROM
        FINAL_PROJECT.PUBLIC.GAMES
    UNION ALL -- subquery to append all data from games as a single column oh team, and the score to later find the ppg using window function
    SELECT
        game_id,
        date,
        away_team_id team_id,
        away_score score
    FROM
        FINAL_PROJECT.PUBLIC.GAMES
    ) a 
LEFT JOIN FINAL_PROJECT.PUBLIC.TEAMS t ON t.team_id = a.team_id
ORDER BY 2,1

-- 10. Home stadium indoor/outdoor teams playing outdoor
--     > Finding the home stadium of away team (if it's indoor/outdoor) and find if it has any effect to the their score if they play in outdoor stadium
--     > hypothesis is indoor home stadium team will play worse if they play in outdoor stadium
/*
Features:
- GROUP BY, Aggregate function
- SUBQUERY -> CTE  (Common Table Expression)
- JOINS
- WINDOW FUNCTIONS (row_number over partition by) 
*/

WITH home_venue AS (
    SELECT
        *
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (PARTITION BY season, team_id ORDER BY cnt DESC) rnk
            -- sometimes there is multiple stadium that the data says a home stadiums for a single team, so finding the only 1 with most home games
        FROM (
            SELECT
                g.season,
                t.team_id,
                t.team_name,
                s.venue_name,
                s.venue_city,
                s.venue_state,
                s.indoor,
                COUNT(*) cnt
            FROM
                FINAL_PROJECT.PUBLIC.GAMES g
            LEFT JOIN FINAL_PROJECT.PUBLIC.TEAMS t ON t.team_id = g.home_team_id -- finding only the home team
            LEFT JOIN FINAL_PROJECT.PUBLIC.STADIUMS s ON g.stadium_id = s.stadium_id -- finding only the home team
            WHERE
                venue_state IS NOT NULL -- only in the US
            GROUP BY 1,2,3,4,5,6,7 -- order by select column 1-7 for ease of use use number
            ) a -- subquery to find the home stadium for each team and each season
        ) b
    WHERE
        rnk = 1 -- finding the stadium with the most count of home games for each team (partition by season and team id)
) 

SELECT
    g.season,
    s.indoor venue_indoor,
    h.indoor away_team_home_venue_indoor,
    AVG(g.away_score)
FROM FINAL_PROJECT.PUBLIC.GAMES g
LEFT JOIN home_venue h ON g.away_team_id = h.team_id
LEFT JOIN FINAL_PROJECT.PUBLIC.STADIUMS s ON s.stadium_id = g.stadium_id
WHERE
    s.indoor = FALSE -- only find where the games is outdoor
GROUP BY 1,2,3
ORDER BY 1,2,3


-- 11. All data combined with ppg
--     > additional -> all data we used for regression -> same explanation as no 9
WITH ppg AS (
    SELECT
        game_id,
        team_id,
        score,
        AVG(score) OVER (PARTITION BY team_id ORDER BY date ROWS BETWEEN 10 PRECEDING AND 1 PRECEDING) avg_ppg_10
    FROM (
        SELECT
            game_id,
            date,
            home_team_id team_id,
            home_score score
        FROM
            FINAL_PROJECT.PUBLIC.GAMES
        UNION ALL
        SELECT
            game_id,
            date,
            away_team_id team_id,
            away_score score
        FROM
            FINAL_PROJECT.PUBLIC.GAMES
        ) a
    )

SELECT
    -- CASE WHEN b.home_team IS NULL THEN 'error' ELSE 'joined' END a, -- just for checking, keeping it here just in case
    -- COUNT(*),
    g.game_id, 
    -- COUNT(*),
    g.season, 
    g.week, 
    g.date,
    DATEADD(hour, -4, g.date),
    t.TEAM_NAME home_team, 
    t1.TEAM_NAME away_team, 
    g.home_score, 
    g.away_score, 
    g.total_points, 
    s.venue_name, 
    s.venue_city,
    s.venue_state, 
    s.indoor,
    w.avg_temp,
    w.rain_sum,
    w.wind_speed_avg,
    w.snowfall_sum,
    w.is_indoor,
    w.rain_any,
    w.snow_any,
    b.*,
    ppg_home.avg_ppg_10 home_team_10games_ppg,
    ppg_away.avg_ppg_10 away_team_10games_ppg
FROM FINAL_PROJECT.PUBLIC.GAMES g
LEFT JOIN FINAL_PROJECT.PUBLIC.TEAMS t ON t.TEAM_ID = g.home_team_id
LEFT JOIN FINAL_PROJECT.PUBLIC.TEAMS t1 ON t1.TEAM_ID = g.away_team_id
LEFT JOIN FINAL_PROJECT.PUBLIC.WEATHER w ON w.game_id = g.game_id
LEFT JOIN FINAL_PROJECT.PUBLIC.STADIUMS s ON s.stadium_id = g.stadium_id
LEFT JOIN FINAL_PROJECT.PUBLIC.BETTING_DATA b ON b.schedule_date BETWEEN DATE(DATEADD(DAY, -1, g.date)) AND DATE(DATEADD(DAY, 1, g.date)) AND b.home_team LIKE '%' || t.team_name || '%'
LEFT JOIN ppg ppg_home ON ppg_home.team_id = g.home_team_id AND ppg_home.game_id = g.game_id
LEFT JOIN ppg ppg_away ON ppg_away.team_id = g.away_team_id AND ppg_away.game_id = g.game_id
ORDER BY 1



