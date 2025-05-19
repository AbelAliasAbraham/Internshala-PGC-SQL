

CREATE TABLE matches ( id int, city varchar, date date, player_of_match varchar, venue varchar, neutral_venue int, team1 varchar,  team2 varchar,  toss_winner varchar,  toss_decision varchar,  winner varchar, result_mode varchar,result_margin int, eliminator varchar, method_dl varchar, umpire1 varchar, umpire2 varchar ); 

copy matches from 'C:\Program Files\PostgreSQL\16\data\Data\IPL Dataset\IPL_matches.csv'with csv header; 

CREATE TABLE deliveries ( id int,  inning int,  over int,  ball int,  batsman varchar,  non_striker varchar, bowler varchar,  batsman_runs int, extra_runs int,  total_runs int, wicket_ball int, dismissal_kind varchar, player_dismissed varchar, fielder varchar, extras_type varchar, batting_team varchar,bowling_team varchar); 

copy deliveries from 'C:\Program Files\PostgreSQL\16\data\Data\IPL Dataset\IPL_Ball.csv'with csv header;

#Aggressive batters
select player,total_runs,balls_faced, round(CAST(strike_rate as NUMERIC),3) as rounded_strike_rate from(
	select batsman as player,sum(batsman_runs) as total_runs, count(ball) as balls_faced,
		(cast(sum(batsman_runs)as float)/count(ball))*100 as strike_rate
	from Deliveries where extras_type!='wides'
	 group by batsman) as player_stats where balls_faced>=500 order by strike_rate desc limit 10;

#ANCHOR BATSMAN
with PlayerStats as(
	select batsman as player, sum(batsman_runs) as total_runs, count(distinct id) as total_matches,count(wicket_ball) filter(where wicket_ball=1) as times_dismissed
	from Deliveries group by batsman having count (distinct id)>28 and count(wicket_ball) filter(where wicket_ball=1)>0
	)
select player, total_runs, total_matches,times_dismissed,round(cast(cast(total_runs as FLOAT)/times_dismissed as numeric),2) as average
	from PlayerStats order by average desc limit 10;

#Hard Hitters
select player, total_runs, boundary_runs, ROUND(cast(boundary_percentage as numeric),2) as rounded_boundary_percentage
from (
  select batsman as player, sum(batsman_runs) as total_runs, count(distinct id) as total_matches,
         sum(case when batsman_runs >= 4 then batsman_runs else 0 end) as boundary_runs,
         cast(sum(case when batsman_runs >= 4 then batsman_runs else 0 end) as float) / nullif(sum(batsman_runs), 0) * 100 as boundary_percentage
  from deliveries
  group by batsman
  having count(distinct id) > 28
) as Player_Stats
order by boundary_percentage desc
limit 10;

#Allrounders
WITH BattingStats AS (
  SELECT batsman, SUM(batsman_runs) AS total_runs, SUM(ball) AS total_balls,
         (SUM(batsman_runs) / SUM(ball)) * 100 AS batting_strike_rate
  FROM deliveries
  WHERE batsman IS NOT NULL
  GROUP BY batsman
  HAVING sum(total_runs) >= 500
),
BowlingStats AS (
  SELECT bowler, SUM(ball) AS total_balls_bowled, SUM(total_runs) AS total_runs_conceded, SUM(over) AS total_overs,
         (SUM(extra_runs) / SUM(over)) AS bowling_economy,
         SUM(CASE WHEN dismissal_kind IS NOT NULL THEN 1 ELSE 0 END) AS wickets_taken  -- Count deliveries with wickets (assuming dismissal_kind indicates wickets)
  FROM deliveries
  WHERE bowler IS NOT NULL
  GROUP BY bowler
  HAVING sum(ball) >= 300
),
AllRounderStats AS (
  SELECT bs.batsman AS player, bs.total_runs, bs.total_balls,be.total_runs_conceded, be.total_overs
  FROM BattingStats bs
  INNER JOIN BowlingStats be ON bs.batsman = be.bowler
)
SELECT *
FROM AllRounderStats




#economic bowlers

select bowler, sum(total_runs) as total_runs_conceded,
	sum(case when extras_type!='wides' and extras_type!='noballs' then 1 else 0 end) as balls_bowled, 
	round(cast(cast(sum(total_runs)as float)/(sum(case when extras_type!='wides' and extras_type!='noballs' then 1 else 0 end)/6)as numeric),3) as economy
from deliveries
 group by bowler having sum(case when extras_type!='wides' and extras_type!='noballs' then 1 else 0 end)>=500 order by economy asc limit 10;

#wicket taking bowlers
with bowlerstats as(
	select bowler,
	sum(case when wicket_ball=1 then 1 else 0 end) as wickets,
	sum(case when extras_type!='wides' and extras_type!='noballs' then 1 else 0 end) as valid_balls
	from deliveries
	group by bowler
	having sum(case when extras_type!='wides' and extras_type!='noballs' then 1 else 0 end)>=500
)
select bowler, valid_balls,wickets,
	round(cast((cast(valid_balls as float)/wickets)as numeric),3) as strike_rate from bowlerstats where wickets>0 order by strike_rate asc limit 10;

#additional questions

#question 1
select count(distinct city) as city_count from matches

#question 2
CREATE TABLE deliveries_v02 as 
	select 	*,
		 CASE WHEN total_runs >= 4 THEN 'boundary'
		     WHEN total_runs = 0 THEN 'dot'
		     ELSE 'other'
		     END as ball_result
	FROM deliveries
	
select * from deliveries_v02;

#question 3
SELECT 	  ball_result,
		  count(*)
	FROM 	  deliveries_v02
	WHERE 	  ball_result in ('boundary','dot')
	GROUP BY  ball_result


#question 4
SELECT 	  batting_team,
		  count(*) AS total_boundaries
	FROM 	  deliveries_v02
	WHERE 	  ball_result = 'boundary' 
	GROUP BY  batting_team
	ORDER BY  total_boundaries desc

#question 5
	SELECT 	  bowling_team,
		  count(*) as total_dot_balls
	FROM 	  deliveries_v02
	WHERE 	  ball_result = 'dot'
	GROUP BY  bowling_team
	ORDER BY  total_dot_balls desc

#question 6
SELECT 	  dismissal_kind,
		  count(*) as total_dismissals
	FROM 	  deliveries
	WHERE	  dismissal_kind <> 'NA'
	GROUP BY  dismissal_kind
	order by total_dismissals desc

#question 7
SELECT 	  bowler,
		  sum(extra_runs) AS total_extras
	FROM 	  deliveries
	GROUP BY  bowler
	ORDER BY  total_extras desc
	LIMIT 	  5

#question 8
CREATE TABLE deliveries_v03 AS 
	Select	a.*,
		b.venue,
		b.date
	FROM 	deliveries_v02 AS a
	JOIN 	matches AS b
	ON 		a.id = b.id
	
	SELECT * FROM deliveries_v03	

#question 9
SELECT 	  venue,
	          sum(total_runs) as total_runs_scored
	FROM 	  deliveries_v03
	GROUP BY  venue
	ORDER BY  total_runs_scored desc

#question 10
SELECT 	  extract( year from date ) AS year,
	          sum(total_runs) as total_runs_scored
	FROM 	  deliveries_v03
	WHERE 	  venue = 'Eden Gardens'
	GROUP BY  year
	ORDER BY  total_runs_scored desc
