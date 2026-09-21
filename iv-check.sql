-- Oracle-parser-mode probe: ALTER TABLE ... ALTER COLUMN TYPE against a column
-- that a materialized view depends on.
--
-- Must be run against a cluster created with "initdb -m oracle" and connected
-- through the Oracle port (ivorysql.port), so ivorysql.compatible_mode = oracle.
--
-- Assertions encode PostgreSQL behaviour: when a materialized view depends on
-- the column, ALTER COLUMN TYPE must be refused and the materialized view must
-- stay fully usable.  Anything else prints a "BUG:" line.
\pset pager off
\echo '== session'
show ivorysql.compatible_mode;
select version();

\echo ''
\echo '== scenario 1: materialized view on the altered column (varchar stays varchar, only length grows)'
drop table if exists probe_t1 cascade;
drop materialized view if exists probe_m1;
create table probe_t1(a char(20), b int);
insert into probe_t1 values ('one', 1);
create materialized view probe_m1 as select a, b from probe_t1;
select 'state before' as step, (select count(*) from probe_m1) as rows;

do $probe$
declare
  refused boolean := false;
begin
  begin
    execute 'alter table probe_t1 alter column a type char(25)';
  exception when others then
    refused := true;
    raise notice 'ALTER refused (sqlstate %): %', sqlstate, sqlerrm;
  end;
  if not refused then
    raise exception 'BUG: ALTER TABLE ... ALTER COLUMN TYPE was applied even though materialized view probe_m1 depends on that column';
  end if;
end
$probe$;

select 'state after' as step, c.relkind, c.relnatts,
       (select count(*) from pg_rewrite r where r.ev_class = c.oid) as rewrite_rules,
       (select count(*) from pg_force_view f where f.fvoid = c.oid) as force_view_rows
  from pg_class c where c.relname = 'probe_m1';

do $probe$
declare
  n int;
  attrs int;
  rules int;
  fv int;
begin
  select relnatts into attrs from pg_class where relname = 'probe_m1';
  select count(*) into rules from pg_rewrite r join pg_class c on c.oid = r.ev_class where c.relname = 'probe_m1';
  select count(*) into fv from pg_force_view f join pg_class c on c.oid = f.fvoid where c.relname = 'probe_m1';
  if attrs is distinct from 2 then
    raise exception 'BUG: materialized view probe_m1 has % attributes, expected 2', attrs;
  end if;
  if rules is distinct from 1 then
    raise exception 'BUG: materialized view probe_m1 has % pg_rewrite rows, expected its _RETURN rule', rules;
  end if;
  if fv <> 0 then
    raise exception 'BUG: materialized view probe_m1 was turned into a force view (% pg_force_view rows)', fv;
  end if;
  select count(*) into n from probe_m1;
  if n <> 1 then
    raise exception 'BUG: materialized view probe_m1 returns % rows, expected 1', n;
  end if;
  refresh materialized view probe_m1;
  select count(*) into n from probe_m1;
  if n <> 1 then
    raise exception 'BUG: materialized view probe_m1 is unusable after REFRESH (% rows)', n;
  end if;
  raise notice 'materialized view probe_m1 is intact';
end
$probe$;

\echo ''
\echo '== scenario 2: materialized view on the altered column (int -> text, stored data cannot match)'
drop materialized view if exists probe_m2;
drop table if exists probe_t2 cascade;
create table probe_t2(a int);
insert into probe_t2 values (7), (8);
create materialized view probe_m2 as select a from probe_t2;

do $probe$
declare
  refused boolean := false;
begin
  begin
    execute 'alter table probe_t2 alter column a type text';
  exception when others then
    refused := true;
    raise notice 'ALTER refused (sqlstate %): %', sqlstate, sqlerrm;
  end;
  if not refused then
    raise exception 'BUG: ALTER TABLE ... ALTER COLUMN TYPE int->text was applied even though materialized view probe_m2 depends on that column';
  end if;
end
$probe$;

select 'state after' as step, c.relkind, c.relnatts,
       (select count(*) from pg_rewrite r where r.ev_class = c.oid) as rewrite_rules,
       (select count(*) from pg_force_view f where f.fvoid = c.oid) as force_view_rows
  from pg_class c where c.relname = 'probe_m2';

do $probe$
declare
  n int;
  attrs int;
  rules int;
  fv int;
begin
  select relnatts into attrs from pg_class where relname = 'probe_m2';
  select count(*) into rules from pg_rewrite r join pg_class c on c.oid = r.ev_class where c.relname = 'probe_m2';
  select count(*) into fv from pg_force_view f join pg_class c on c.oid = f.fvoid where c.relname = 'probe_m2';
  if attrs is distinct from 1 then
    raise exception 'BUG: materialized view probe_m2 has % attributes, expected 1', attrs;
  end if;
  if rules is distinct from 1 then
    raise exception 'BUG: materialized view probe_m2 has % pg_rewrite rows, expected its _RETURN rule', rules;
  end if;
  if fv <> 0 then
    raise exception 'BUG: materialized view probe_m2 was turned into a force view (% pg_force_view rows)', fv;
  end if;
  select count(*) into n from probe_m2;
  if n <> 2 then
    raise exception 'BUG: materialized view probe_m2 returns % rows, expected 2', n;
  end if;
  refresh materialized view probe_m2;
  select count(*) into n from probe_m2;
  if n <> 2 then
    raise exception 'BUG: materialized view probe_m2 is unusable after REFRESH (% rows)', n;
  end if;
  raise notice 'materialized view probe_m2 is intact';
end
$probe$;

\echo ''
\echo '== control: plain view (informational only, this is the feature requested in issue #1225)'
drop view if exists probe_v1;
drop table if exists probe_t3 cascade;
create table probe_t3(a char(20));
insert into probe_t3 values ('two');
create view probe_v1 as select a from probe_t3;
alter table probe_t3 alter column a type char(25);
select 'plain view after alter' as step, a from probe_v1;
select 'catalog' as step, c.relnatts,
       (select count(*) from pg_rewrite r where r.ev_class = c.oid) as rewrite_rules,
       (select count(*) from pg_force_view f where f.fvoid = c.oid) as force_view_rows
  from pg_class c where c.relname = 'probe_v1';

\echo ''
\echo '== control 2: chained views (informational only)'
create view probe_v2 as select a from probe_v1;
alter table probe_t3 alter column a type char(30);
select 'chain after alter' as step, c.relname, c.relnatts,
       (select count(*) from pg_rewrite r where r.ev_class = c.oid) as rewrite_rules,
       (select count(*) from pg_force_view f where f.fvoid = c.oid) as force_view_rows
  from pg_class c where c.relname in ('probe_v1', 'probe_v2') order by c.relname;
select 'chain v2' as step, a from probe_v2;

\echo ''
\echo '== probe finished'