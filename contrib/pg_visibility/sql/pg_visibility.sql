CREATE EXTENSION pg_visibility;

--
-- recently-dropped table
--
\set VERBOSITY sqlstate
BEGIN;
CREATE TABLE droppedtest (c int);
SELECT 'droppedtest'::regclass::oid AS oid \gset
SAVEPOINT q; DROP TABLE droppedtest; RELEASE q;
SAVEPOINT q; SELECT * FROM pg_visibility_map(:oid); ROLLBACK TO q;
-- ERROR:  could not open relation with OID 16xxx
SAVEPOINT q; SELECT 1; ROLLBACK TO q;
SAVEPOINT q; SELECT 1; ROLLBACK TO q;
SELECT pg_relation_size(:oid), pg_relation_filepath(:oid),
  has_table_privilege(:oid, 'SELECT');
SELECT * FROM pg_visibility_map(:oid);
-- ERROR:  could not open relation with OID 16xxx
ROLLBACK;
\set VERBOSITY default

--
-- check that using the module's functions with unsupported relations will fail
--

-- partitioned tables (the parent ones) don't have visibility maps
create table test_partitioned (a int) partition by list (a);
-- these should all fail
select pg_visibility('test_partitioned', 0);
select pg_visibility_map('test_partitioned');
select pg_visibility_map_summary('test_partitioned');
select pg_check_frozen('test_partitioned');
select pg_truncate_visibility_map('test_partitioned');

create table test_partition partition of test_partitioned for values in (1);
create index test_index on test_partition (a);
-- indexes do not, so these all fail
select pg_visibility('test_index', 0);
select pg_visibility_map('test_index');
select pg_visibility_map_summary('test_index');
select pg_check_frozen('test_index');
select pg_truncate_visibility_map('test_index');

create view test_view as select 1;
-- views do not have VMs, so these all fail
select pg_visibility('test_view', 0);
select pg_visibility_map('test_view');
select pg_visibility_map_summary('test_view');
select pg_check_frozen('test_view');
select pg_truncate_visibility_map('test_view');

create sequence test_sequence;
-- sequences do not have VMs, so these all fail
select pg_visibility('test_sequence', 0);
select pg_visibility_map('test_sequence');
select pg_visibility_map_summary('test_sequence');
select pg_check_frozen('test_sequence');
select pg_truncate_visibility_map('test_sequence');

create foreign data wrapper dummy;
create server dummy_server foreign data wrapper dummy;
create foreign table test_foreign_table () server dummy_server;
-- foreign tables do not have VMs, so these all fail
select pg_visibility('test_foreign_table', 0);
select pg_visibility_map('test_foreign_table');
select pg_visibility_map_summary('test_foreign_table');
select pg_check_frozen('test_foreign_table');
select pg_truncate_visibility_map('test_foreign_table');

-- check some of the allowed relkinds
create table regular_table (a int, b text);
alter table regular_table alter column b set storage external;
insert into regular_table values (1, repeat('one', 1000)), (2, repeat('two', 1000));
vacuum regular_table;
select count(*) > 0 from pg_visibility('regular_table');
select count(*) > 0 from pg_visibility((select reltoastrelid from pg_class where relname = 'regular_table'));
truncate regular_table;
select count(*) > 0 from pg_visibility('regular_table');
select count(*) > 0 from pg_visibility((select reltoastrelid from pg_class where relname = 'regular_table'));

create materialized view matview_visibility_test as select * from regular_table;
vacuum matview_visibility_test;
select count(*) > 0 from pg_visibility('matview_visibility_test');
insert into regular_table values (1), (2);
refresh materialized view matview_visibility_test;
select count(*) > 0 from pg_visibility('matview_visibility_test');

-- regular tables which are part of a partition *do* have visibility maps
insert into test_partition values (1);
vacuum test_partition;
select count(*) > 0 from pg_visibility('test_partition', 0);
select count(*) > 0 from pg_visibility_map('test_partition');
select count(*) > 0 from pg_visibility_map_summary('test_partition');
select * from pg_check_frozen('test_partition'); -- hopefully none
select pg_truncate_visibility_map('test_partition');

-- cleanup
drop table test_partitioned;
drop view test_view;
drop sequence test_sequence;
drop foreign table test_foreign_table;
drop server dummy_server;
drop foreign data wrapper dummy;
drop materialized view matview_visibility_test;
drop table regular_table;
