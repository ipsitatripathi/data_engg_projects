select * from netflix order by title;
alter table netflix alter column title nvarchar(500);
SELECT title FROM netflix WHERE title LIKE '%?_%';

drop table netflix;

CREATE TABLE netflix (
    show_id        NVARCHAR(10) primary key,
    type           NVARCHAR(10) NULL,
    title          NVARCHAR(500) NULL,
    director       NVARCHAR(255) NULL,
    cast           NVARCHAR(1000) NULL,
    country        NVARCHAR(200) NULL,
    date_added     DATE NULL,
    release_year   INT NULL,
    rating         NVARCHAR(20) NULL,
    duration       NVARCHAR(20) NULL,
    listed_in      NVARCHAR(100) NULL,
    description    NVARCHAR(250) NULL
);

-- remove duplicates
select show_id, count(*) from netflix group by show_id having count(*) > 1;

select * from netflix where upper(title) in
(select upper(title) from netflix group by upper(title) having count(*) > 1)
order by upper(title);

with cte as(
select *, ROW_NUMBER() over (partition by title, type order by show_id) as rn from netflix)
select * from cte where rn = 1;

-- new table for listed in, director, country, cast
select show_id, trim(value) as director into netflix_directors from netflix
cross apply string_split(director, ',');
select show_id, trim(value) as country into netflix_countries from netflix
cross apply string_split(country, ',');
select show_id, trim(value) as genre into netflix_genre from netflix
cross apply string_split(listed_in, ',');
select show_id, trim(value) as cast into netflix_cast from netflix
cross apply string_split(cast, ',');

select * from netflix_genre;

-- datatype conversion for date_added
with cte as(
select *, ROW_NUMBER() over (partition by title, type order by show_id) as rn from netflix)
select show_id, type, title, cast(date_added as date) as date_added, release_year, rating, duration, description
from cte where rn=1;

select show_id, country from netflix_raw where country is null;

-- director, country mapping
select director, country from netflix_countries nc inner join netflix_directors nd
on nc.show_id = nd.show_id group by director, country order by director;

-- data analysis
/* Q1 for each director, count the number of movies and tv shows created by them in separate columns for 
directors who have created tv shows and movies both */
select nd.director director, 
count(distinct case when type = 'Movie' then nr.show_id end) as no_of_movies,
count(distinct case when type = 'TV Show' then nr.show_id end) as no_of_tv_shows
from netflix nr inner join netflix_directors nd on nr.show_id = nd.show_id
group by nd.director
having count(distinct nr.type) > 1;

/* Q2 which country has highest number of comedy movies */
select top 1 nc.country country, count(distinct ng.show_id) number from netflix_genre ng 
inner join netflix_countries nc on ng.show_id = nc.show_id
inner join netflix nr on ng.show_id = nc.show_id where ng.genre = 'Comedies' and nr.type = 'Movie'
group by nc.country
order by number desc;

/* Q3 for each year (as per date added to netflix), which director has maximum number of movies released  */
with cte as (
select nd.director director, YEAR(nr.date_added) as added_year, count(distinct nr.show_id) number_of_movies from netflix nr
inner join netflix_directors nd on nd.show_id = nr.show_id where nr.type = 'Movie'
group by nd.director, YEAR(nr.date_added)),
cte2 as (
select *, row_number() over (partition by added_year order by number_of_movies desc, director) as rn
from cte 
--order by added_year, number_of_movies desc
)
select * from cte2 where rn=1;

/* Q4 what is average duration of movies in each genre  */
select ng.genre , avg(cast(replace(duration, ' min', '') as int)) duration_int
from netflix nr inner join netflix_genre ng on nr.show_id = ng.show_id where nr.type = 'Movie'
group by ng.genre
order by duration_int desc;

/* Q5 find the list of directors who have created horror and comedy movies both, display director names along with
number of horror and comedy movies done by them */
select nd.director, count(case when ng.genre = 'Comedies' then nd.show_id end) as comedies_count, 
count(case when ng.genre = 'Horror Movies' then nd.show_id end) as horror_count
from netflix nr inner join netflix_genre ng on nr.show_id = ng.show_id inner join netflix_directors nd 
on nd.director = nr.director
where nr.type='Movie' and ng.genre in ('Comedies','Horror Movies')
group by nd.director having count(distinct ng.genre) = 2 ;