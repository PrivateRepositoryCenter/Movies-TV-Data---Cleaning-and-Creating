UPDATE
    cinema.cinema4
SET
    Year = REPLACE(Year,'–','-')
WHERE
    Year IS NOT NULL;

# Create a new table to work with    
create table CinemaTable (
select * from cinema.cinema4 );   

# Trim leading white space of movie titles
UPDATE CinemaTable
SET MOVIES = TRIM(' ' FROM MOVIES);

# Uses the Year to create a status
#drop table AiringStatus;
create table AiringStatus (
Select * 
FROM 
(SELECT MOVIES, Year, 
   CASE
      WHEN Year like '%____-____%' THEN 'Series Concluded'
      WHEN Year like  '%____- %' THEN 'On Going'
      WHEN Year like '%--%' THEN 'Single Series/Movie' # Movie/TV Show with a single Year 
      WHEN Year rlike '([0-9])'THEN 'Single Series/Movie'
      ELSE 'Unknown' # Year is blank or does not conatain number
   END AS Airing_Status
FROM CinemaTable) as myalias);

# Seperates the Year into a start and end year
#drop table YearSeperation;
create table YearSeperation (
select MOVIES, Year, Airing_Status, YearReleased, YearEnded
from 
(	
select *,
REGEXP_REPLACE(YR, '[a-zA-Z()/-]+', '') as YearReleased, 
REGEXP_REPLACE(YE, '[a-zA-Z()/-]+', '') as YearEnded 
from 
	(
	select MOVIES, YEAR, Airing_Status,
	substring_index(Year,'-', 1) as YR,
	substring_index(Year,'-', -1) as YE
    from AiringStatus
	) as sub1
) as sub2 );

# Single Season/ Movies: The Year Released is the same as Year Ended
UPDATE YearSeperation
SET YearReleased = YearEnded
WHERE Airing_Status like 'Single Series/Movie';

# remove white space
UPDATE YearSeperation
SET YearReleased = TRIM(' ' FROM YearReleased) ;

select * from YearSeperation;
drop table AiringStatus; # don't need this anymore

# Create New Table. Groups Duplicate rows together
#drop table CinemaAiringYears;
create table CinemaAiringYears (
select * 
from YearSeperation
# This insures that unique rows are not eaten
group by Movies, Year, Airing_Status, YearReleased, YearEnded 
order by Movies) ;

# Example: Two Different Bad Bloods
select * from CinemaAiringYears where movies like '%Bad Blood%';

drop table YearSeperation; # do not need anymore



# Contains Movie name, and Max/Min/Avg Ratings for each movie
#drop table CinemaRatings;
create table CinemaRatings (
select * 
from (
		select Movies, Year,
			CASE
			WHEN RATING  not like '' then max(Rating)
            else 'N/A'
            END AS MaxRating,
            
			CASE
			WHEN RATING not like '' then min(Rating)
            else 'N/A'
            END AS MinRating,
            
			CASE
			WHEN RATING not like '' then round(avg(RATING),1)
            else 'N/A'
            END AS AvgRating
            
            from CinemaTable
            group by MOVIES, Year
            order by MOVIES) as myalias );

select * from CinemaRatings;


create temporary table tempStar1 as (
select Movies, Year, Stars, 
substring_index(Stars,'|', 1) as Director,
substring_index(Stars, '|', -1) as Actors
from CinemaTable
order by Movies); 

select * from tempStar1;

UPDATE tempStar1
SET Director = '' 
WHERE Director like '%Star:%' ;

UPDATE tempStar1
SET Director = '' 
WHERE Director like '%Stars:%' ;

UPDATE tempStar1
SET Actors = '' 
WHERE Actors like '%Director:%' ;

UPDATE tempStar1
SET Actors = '' 
WHERE Actors like '%Directors:%' ;

# Leaves only the names
UPDATE tempStar1
SET Director = REPLACE(Director,'Director:','') ;
UPDATE tempStar1
SET Director = REPLACE(Director,'Directors:','') ;

# Leaves only the names 
UPDATE tempStar1
SET Actors = REPLACE(Actors,'Star:','') ;
UPDATE tempStar1
SET Actors = REPLACE(Actors,'Stars:','') ;


# Remove excess white space
UPDATE tempStar1
SET Director = Replace(Director, '  ', '');
UPDATE tempStar1
SET Actors = Replace(Actors, '  ', '');


SET session group_concat_max_len=15000;


create temporary table tempStar2(
SELECT Movies, Year, Actors, 
GROUP_CONCAT(Distinct Actors SEPARATOR ',') as GA FROM tempStar1 
GROUP BY Movies, Year);

# ACTORS
drop table CinemaActors;
create table CinemaActors (
select Movies, Year,
# GA7 Add space between First,Middle,Last
 REGEXP_REPLACE(GA6, '(?-i)([a-z])([A-Z])', '$1 $2') as Actors
# GA6 Remove repeating white space
from ( select *, REGEXP_REPLACE (GA5, '\\s\\s', '') as GA6
# GA5 Add comma between full names
from ( select *, REGEXP_REPLACE (GA4, '(?-i)([a-z])\\s([A-Z])', '$1 , $2') as GA5
# GA4 Remove names that are repeating in the string
from ( select *, REGEXP_REPLACE (GA3, '\\b(\\w+)\\b(?=.*?\\b\\1\\b)', '') as GA4 
# GA3 replace comma with space
from ( select *, REGEXP_REPLACE (GA2 , ',', ' ') as GA3 
# GA2 remove white space
from ( select *,REGEXP_REPLACE(GA, '\\s', '') as GA2 #remove all space
from tempStar2 ) 
as myalias ) as myalias2) as myalias3) as myalias4) as myalias5);




create temporary table tempStar3(
SELECT Movies, Year, Director, 
GROUP_CONCAT(Distinct Director SEPARATOR ',') as GD FROM tempStar1 GROUP BY Movies, Year);

# Directors
drop table CinemaDirectors;
create table CinemaDirectors (
select Movies, Year,
# GD7 Add space between First,Middle,Last
 REGEXP_REPLACE(GD6, '(?-i)([a-z])([A-Z])', '$1 $2') as Directors
# GD6 Remove repeating white space
from ( select *, REGEXP_REPLACE (GD5, '\\s\\s', '') as GD6
# GD5 Add comma between full names
from ( select *, REGEXP_REPLACE (GD4, '(?-i)([a-z])\\s([A-Z])', '$1 , $2') as GD5
# GD4 Remove names that are repeating in the string
from ( select *, REGEXP_REPLACE (GD3, '\\b(\\w+)\\b(?=.*?\\b\\1\\b)', '') as GD4 
# GD3 replace comma with space
from ( select *, REGEXP_REPLACE (GD2 , ',', ' ') as GD3 
# GD2 remove white space
from ( select *,REGEXP_REPLACE(GD, '\\s', '') as GD2 #remove all space
from tempStar3 ) 
as myalias ) as myalias2) as myalias3) as myalias4) as myalias5);


#drop table CinemaVotes;
create table CinemaVotes (
select Movies, Year, sum(cast(replace(Votes, ',' , '') as unsigned)) as TotalVotes
from CinemaTable
group by Movies, Year
order by Movies);
#select * from CinemaVotes;

#drop Table CinemaGross;
create Table CinemaGross (
select Movies, Year, TotalNumericGross, concat('$', TotalNumericGross) as TotalGross
#Get sum of numeric gross per movie
from ( select * , sum(NumericGross) as TotalNumericGross
# Converting $string to decimal value 
from (select Movies, Year, 
	CAST(REPLACE(REPLACE(IFNULL(Gross,0),',',''),'$','') AS DECIMAL(10,2)) as NumericGross
from CinemaTable
	 ) as myalias 
	group by Movies, Year ) as myalias2
group by Movies, Year
order by Movies);
#select * from CinemaGross;


create temporary table tempGenre (select Movies, Year, 
GROUP_CONCAT(Distinct Genre SEPARATOR ',') as GG from CinemaTable 
GROUP BY Movies, Year);
#select * from tempGenre;

#drop table CinemaGenre;
create table CinemaGenre (
select Movies, Year, 
# GG6 add commas
REGEXP_REPLACE( GG5, '([a-z])\\s([a-z])', '$1 , $2') as Genres
# GA5 Remove leading white space
from ( select *, REGEXP_REPLACE (GG4, '^\\s*', '') as GG5
# GA4 Remove genres that are repeating in the string
from ( select *, REGEXP_REPLACE (GG3, '\\b(\\w+)\\b(?=.*?\\b\\1\\b)', '') as GG4 
# GG3 replace comma with space
from ( select *, REGEXP_REPLACE (GG2 , ',', ' ') as GG3 
# GG2 remove white space
from ( select *,REGEXP_REPLACE(GG, '\\s', '') as GG2 #remove all space
from tempGenre ) 
as myalias ) as myalias2) as myalias3) as myalias4);

## ALL NEW TABLES ##
/*
select * from CinemaAiringYears;
select * from CinemaActors;
select * from CinemaDirectors;
select * from CinemaRatings;
select * from CinemaVotes;
select * from CinemaGross;
select * from CinemaGenre;
*/

# Concluded Series that ran the most years
select Movies,(YearEnded - YearReleased) as YearsRan from CinemaAiringYears
where YearEnded not like ' '
order by (YearEnded - YearReleased) desc;

# Movies/TV Shows with the highest GROSS released in the 90s
select CinemaAiringYears.Movies, CinemaAiringYears.YearReleased, CinemaGross.TotalGross from
CinemaAiringYears
left outer join CinemaGross ON CinemaAiringYears.Movies = CinemaGross.Movies 
							AND CinemaAiringYears.Year = CinemaGross.Year
where YearReleased < 2000 AND YearReleased > 1989
order by TotalNumericGross desc
limit 10;

# On Going RomComs with the Highest Average Rating
select CinemaAiringYears.Movies as Title, CinemaAiringYears.Airing_Status, 
	   CinemaRatings.AvgRating, 
       CinemaGenre.Genres
from CinemaAiringYears
		left outer join CinemaRatings on CinemaAiringYears.Movies = CinemaRatings.Movies 
									AND CinemaAiringYears.year = CinemaRatings.Year
		left outer join CinemaGenre on CinemaAiringYears.Movies = CinemaGenre.Movies 
									AND CinemaAiringYears.year = CinemaGenre.Year
where Genres like '%Romance%'
and  Genres like '%Comedy%'
and AvgRating not like 'N/A'
and Airing_Status = 'On Going'
order by CinemaRatings.AvgRating desc;

 
# Shows the movies when there are at least 4 more actors than directors
# so long as the number of directors is not 0
select * from
(select CinemaActors.Movies as Title, 
		CASE
			WHEN CinemaActors.Actors not like '' THEN LENGTH(CinemaActors.Actors)- LENGTH(Replace(CinemaActors.Actors, ',', '')) + 1 
            ELSE 0
		END AS NumberOfActors,
        CASE 
			WHEN CinemaDirectors.Directors not like '' THEN LENGTH(CinemaDirectors.Directors) - LENGTH(Replace(CinemaDirectors.Directors, ',', '')) + 1
            ELSE 0
		END AS NumberOfDirectors,
		CinemaActors.Actors,
		CinemaDirectors.Directors
from CinemaActors
left outer join CinemaDirectors on CinemaActors.Movies = CinemaDirectors.Movies
				and CinemaActors.Year = CinemaDirectors.Year) as myalias
having NumberOfActors > NumberOfDirectors +3 AND NumberOfDirectors > 0
order by NumberOfActors desc , NumberOfDirectors desc;


# Unions the Actors and Directors, creates NotablePeople column
drop table AD;
create table AD (
select Movies, Actors as NotablePeople from CinemaActors
UNION
select Movies, Directors as NotablePeople from CinemaDirectors
order by Movies);
select * from AD;

# Quentin Taratino and Zack Snyder films in order of TotalVotes
select CinemaVotes.Movies, CinemaVotes.TotalVotes,
		CinemaDirectors.Directors
from CinemaVotes 
left join CinemaDirectors on CinemaVotes.Movies = CinemaDirectors.Movies
							AND CinemaVotes.Year = CinemaDirectors.Year
where CinemaDirectors.Directors like '%Zack Snyder%' 
	  OR CinemaDirectors.Directors like '%Quentin Tarantino%'
order by CinemaVotes.TotalVotes;





