-- Active: 1784625275719@@127.0.0.1@3306

SELECT * FROM favorites WHERE parent_id IS NULL ORDER BY ord;
SELECT p.ord, p.name as folder, f.name, f.url, f.tile_image, f.ord
	FROM favorites f, favorites p
	WHERE p.id  = f.parent_id
	ORDER BY p.ord, f.ord
	limit 500;

# добавление картинок в сохранённые
ATTACH DATABASE 'D:\ownCloud\test\vivaldi\vivaldi.db' AS vivaldi;

UPDATE favorites
SET tile_image = (
    SELECT v.preview
    FROM vivaldi.favorites AS v
    WHERE v.url = favorites.url
    LIMIT 1
)
WHERE url IN (
    SELECT v.url FROM vivaldi.favorites AS v WHERE v.preview IS NOT NULL
);

DETACH DATABASE vivaldi;

-- выборка сохранёммых мудрых мыслей из чата Telegram
select a.cnt, a.header, datetime(timestamp, 'unixepoch', 'localtime') date_time, text, hash
	from telegram_chat a 
--	where text like '%Что сказать%'
	order by 3 desc;
	
select a.cnt, a.header, length(a.text) len, a.text from telegram_chat a where a.header = 'Смысли' order by 3 desc;
select * from telegram_chat where header = 'Смысли' and length(text) > 300 or text like '%Смысли%';
delete from telegram_chat where header = 'Смысли' and length(text) > 300 or lower(text) like 'Привет!%';
select count(*) from telegram_chat;

CREATE TABLE "telegram_chat" (
  "cnt" integer NOT NULL,
  "header" TEXT(50) NOT NULL,
  "timestamp" integer NOT NULL,
  "text" TEXT(4000),
  "hash" integer NOT NULL,
  PRIMARY KEY ("cnt", "header", "timestamp", "hash")
);

select ROW_NUMBER() OVER(ORDER BY u.counter desc) as ord, 0 as id_up, f.id, f.name, 'url' as type, u.counter, f.url, a.ip, i.icon, f.preview, f.id_up as g_id, 0 as width, 0 as height from hurls u, favorites f, addresses a, images i where u.url = replace(replace(replace(replace(f.url,'https://www.', ''), 'http://www.', ''), 'https://',''), 'http://', '') and a.baseurl = f.baseurl and i.url = f.url and not exists (select null from favorites_best b where b.id=f.id) limit 10;

select f.url, f.preview, s.width, s.height from favorites f, preview_size s	where s.id = f.id;

select ifnull(o.ord, 999) ord, f.id_up, f.id, f.name, f.favcounter, f.url
	from favorites f
	left join groups_ord o
	  on f.id = o.id
	where f.ord > 0 and f.type = 'folder'
	  order by ord
		;

select id, ord, id_up, name, favcounter, url from view_groups order by ord;
select * from favorites f where f.type = 'folder' and ord > 0 order by 1;
select * from favorites f where url like '%perplex%' or url like '%gemini%' order by 1;

select * from groups_ord order by ord;

drop table groups_ord;
create table groups_ord (
	ord	INTEGER NOT NULL,
	id      INTEGER,
	name    TEXT,
	PRIMARY KEY(id));

delete from groups_ord where id=186;
insert into groups_ord select (select max(ord) from groups_ord) + (ROW_NUMBER() OVER(ORDER BY ord))*10, id, name from favorites f where f.ord > 0 and f.type = 'folder' and not exists (select null from groups_ord b where b.id = f.id);

update favorites set ord=43 where ord=372;
commit;

select * from favorites_best;

insert into favorites_best values(12,55);

update favorites_best set id=145 where ord=8;

commit;

drop TABLE favorites;
CREATE TABLE favorites (
	ord	INTEGER NOT NULL,
	id_up   INTEGER,
	id      INTEGER,
	name    TEXT,
	type    text default 'url',
	favcounter INTEGER default 0,
	url	    TEXT,
	baseurl TEXT,
	preview text,
	counter  INTEGER,
	lastdateopen NUMERIC,
	PRIMARY KEY(id));
	
drop TABLE favorites_best;
CREATE TABLE favorites_best (
	ord	INTEGER NOT NULL,
	id      INTEGER,
	PRIMARY KEY(ord));

insert into favorites_best (ord, id) values(1, 91);
insert into favorites_best (ord, id) values(7, 54);
insert into favorites_best (ord, id) values(2, 43);
insert into favorites_best (ord, id) values(3, 45);
insert into favorites_best (ord, id) values(6, 50);
insert into favorites_best (ord, id) values(, );
insert into favorites_best (ord, id) values(, );
insert into favorites_best (ord, id) values(, );
insert into favorites_best (ord, id) values(, );
insert into favorites_best (ord, id) values(, );
insert into favorites_best (ord, id) values(11, 56);
insert into favorites_best (ord, id) values(8, 146);
insert into favorites_best (ord, id) values(9, 41);
insert into favorites_best (ord, id) values(10, 190);

select * from favorites_best order by 1;

drop VIEW view_favorites_best;
CREATE VIEW view_favorites_best as
select b.ord, b.id, f.name, f.url, f.preview, f.id_up from favorites_best b, favorites f where b.id = f.id order by 1;
	
select ROW_NUMBER() OVER(ORDER BY u.counter desc) as ord, 0 as id_up, f.id, f.name, 'url' as type, u.counter, f.url, a.ip, i.icon, f.preview, f.id_up as g_id, 0 as width, 0 as height from (select replace(replace(replace(replace(u.url,'https://www.', ''), 'http://www.', ''), 'https://',''), 'http://', '') as url, max(u.title) as title, sum(u.visit_count) as counter, max(u.last_visit_time) as last_visit_time
        from h.urls u 
        where u.last_visit_time &gt; (select max(last_visit_time) from h.urls)-86400*30000000  -- берём только ссылки, последняя дата посещения которых до 30 дней от последнего входа в браузер
        group by replace(replace(replace(replace(u.url,'https://www.', ''), 'http://www.', ''), 'https://',''), 'http://', '')
        order by 3 desc, 4 desc) u, favorites f, addresses a, images i where u.url = replace(replace(replace(replace(f.url,'https://www.', ''), 'http://www.', ''), 'https://',''), 'http://', '') and a.baseurl = f.baseurl and i.url = f.url limit 28;
	
drop table addresses;
CREATE TABLE addresses (
	baseurl TEXT,
	ip		TEXT,
	name    TEXT,
	lastdatechk NUMERIC,
	PRIMARY KEY(baseurl));
	
CREATE TABLE images (
	url	    TEXT,
	icon    TEXT,
	thumbnail TEXT,
	PRIMARY KEY(url));

drop TABLE favorites_del;	
CREATE TABLE favorites_del (
    ord INTEGER NOT NULL,   
    id_up   INTEGER NOT NULL,
    id      INTEGER,         
    name    TEXT,            
    type    TEXT,            
    url     TEXT,
	preview TEXT,
    datedel NUMERIC);        

CREATE TABLE preview_size (
	id      INTEGER,
	width   INTEGER,
	height	INTEGER,
	PRIMARY KEY(id));
	
insert into preview_size values (50, 700, 520);
insert into preview_size values (100, 1000, 800);
insert into preview_size values (201, 1200, 1000);
insert into preview_size values (418, 700, 570);

select * from preview_size;

drop view view_favorites;
CREATE VIEW view_favorites as
select f.ord, f.id_up, f.id, f.name, f.type, f.favcounter, f.url, a.ip, i.icon, f.preview, s.width, s.height
	from favorites f
		left join addresses a on a.baseurl = f.baseurl
		left join images i on i.url = f.url
		left join preview_size s on s.id = f.id;
	
--delete from favorites where type='folder';

select * from favorites where url like '%5077%' order by ord;
select * from favorites_del order by ord;
select * from addresses order by ip;
select * from images;

select * from view_favorites order by 1;

drop view view_groups;
create view view_groups as
select 0 as ord, null as id_up, 0 as id, 'Популярні' as name, 0 as favcounter, 'Популярні' as url
union
select f.ord, f.id_up, f.id, f.name, f.favcounter, f.url
	from favorites f
	where f.type = 'folder'
	  and ord &gt; 0;

select * from view_groups order by ord;

select id, url, baseurl, length(baseurl) from favorites where type='url' and ifnull(baseurl, '') != '';

select ord, id_up, id, url, baseurl, length(baseurl) from favorites f where type='url' and ifnull(baseurl, '') != '' and exists(select null from addresses a where a.baseurl = f.baseurl and a.ip='00.00.00.00') order by ord;

select baseurl, ip from addresses where ip is not null and ip != '00.00.00.00' order by 1;

attach database &quot;vivaldi.db&quot; as v;
attach database &quot;db/history.db&quot; as h;
select * from v.favorites f where f.url like '%#%';

select datetime(13354463578286010 / 1000000 + (strftime('%s', '1601-01-01')), 'unixepoch', 'localtime') dat, datetime(13354463578 + (strftime('%s', '1601-01-01')), 'unixepoch', 'localtime') dat0;

select datetime(13354463578286010, 'unixepoch', 'localtime') dat;

drop view hurls;
create temp view hurls as
    select replace(replace(replace(replace(u.url,'https://www.', ''), 'http://www.', ''), 'https://',''), 'http://', '') as url, max(u.title) as title, sum(u.visit_count) as counter
        from h.urls u 
        where u.last_visit_time &gt; (select max(last_visit_time) from h.urls)-86400*30000000  -- берём только ссылки, последняя дата посещения которых до 30 дней от последнего входа в браузер
        group by replace(replace(replace(replace(u.url,'https://www.', ''), 'http://www.', ''), 'https://',''), 'http://', '')
        order by 3 desc
        limit 50*4;
	
select * from hurls order by counter desc;
select * from h.urls order by visit_count desc;

select u.url, f.name, u.visit_count from h.urls u, v.favorites f
    where u.url = f.url
	order by visit_count desc;


select replace(replace(replace(replace(u.url,'https://www.', ''), 'http://www.', ''), 'https://',''), 'http://', '') url, f.name, u.visit_count 
	from hurls u
	left join favorites f
	  on replace(replace(replace(replace(u.url,'https://www.', ''), 'http://www.', ''), 'https://',''), 'http://', '') = replace(replace(replace(replace(f.url,'https://www.', ''), 'http://www.', ''), 'https://',''), 'http://', '')
	order by visit_count desc;
	
select ROW_NUMBER() OVER(ORDER BY u.counter desc) as ord, 0 as id_up, f.id, f.name, 'url' as type, u.counter, f.url, a.ip, u.dat, i.icon, f.preview, g.ord gord, g.name
	from hurls u, favorites f, addresses a, images i, favorites g
	where u.url = replace(replace(replace(replace(f.url,'https://www.', ''), 'http://www.', ''), 'https://',''), 'http://', '')
	  and a.baseurl = f.baseurl
	  and i.url = f.url
	  and g.id = f.id_up
	limit 7*4;
	  
SELECT date() AS date, 
    time(133513658) AS time,
    datetime() AS datetime,
    julianday() AS julian;

select ROW_NUMBER() OVER(ORDER BY u.counter desc) as ord, 0 as id_up, f.id, f.name, 'url' as type, u.counter, f.url, a.ip, i.icon, f.preview, f.id_up as g_id, 0 as width, 0 as height from hurls u, favorites f, addresses a, images i where u.url = replace(replace(replace(replace(f.url,'https://www.', ''), 'http://www.', ''), 'https://',''), 'http://', '') and a.baseurl = f.baseurl and i.url = f.url;

select b.ord, b.id, f.name, f.url, f.preview, f.id_up from favorites_best b, favorites f where b.id = f.id;
select ROW_NUMBER() OVER(ORDER BY u.counter desc) as ord, 0 as id_up, f.id, f.name, 'url' as type, u.counter, f.url, a.ip, i.icon, f.preview, f.id_up as g_id, 0 as width, 0 as height 
	from hurls u, favorites f, addresses a, images i 
	where u.url = replace(replace(replace(replace(f.url,'https://www.', ''), 'http://www.', ''), 'https://',''), 'http://', '') 
	  and a.baseurl = f.baseurl 
	  and i.url = f.url
	  and not exists (select null from favorites_best b where b.id=f.id)
;
select b.ord, 0, 0 as id_up, f.id, f.name, 'url' as type, 0 as counter, f.url, a.ip, i.icon, f.preview, f.id_up as g_id, 0 as width, 0 as height 
	from favorites f, addresses a, images i, favorites_best b
	where a.baseurl = f.baseurl 
	  and i.url = f.url
	  and b.id = f.id
limit 7*4
;
select * from hurls where url like '%vk.com%';
select * from addresses;
select * from images;
select * from view_favorites_best;

select f.url, f.preview, s.width, s.height from favorites f, preview_size s	where s.id = f.id;

ATTACH DATABASE &quot;db/history.db&quot; AS h;
create temp view hurls as
select replace(replace(replace(replace(u.url,'https://www.', ''), 'http://www.', ''), 'https://',''), 'http://', '') as url, max(u.title) as title, sum(u.visit_count) as counter, max(u.last_visit_time) as last_visit_time
	from h.urls u
	
	where u.last_visit_time &gt; (select max(last_visit_time) from h.urls)-86400*30000000  -- берём только ссылки, последняя дата посещения которых до 30 дней от последнего входа в браузер
	group by replace(replace(replace(replace(u.url,'https://www.', ''), 'http://www.', ''), 'https://',''), 'http://', '')
	order by 3 desc, 4 desc;
