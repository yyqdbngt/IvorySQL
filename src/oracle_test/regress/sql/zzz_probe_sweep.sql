--
-- PROBE ONLY (characterisation, not evidence): the remaining sites the reviewer
-- listed, measured instead of read.
-- A: heap.c:499  rowid as a column name, per mode and per DDL path
-- B: heap.c:3321 virtual generated column + a function from the initdb OID range
-- C: namespace.c:1380/1559 plisql OUT-argument resolution, per session mode
-- D: namespace.c:4590 implicit search path, per session mode
-- E: pg_proc.c:715/727 composite (%ROWTYPE) parameter type: is a dependency
--    recorded, and does DROP TABLE leave a dangling type reference behind?
--

-- A ------------------------------------------------------------------
SET ivorysql.compatible_mode TO oracle;
CREATE TABLE ora_a1 (rowid int, a int);                 -- CREATE TABLE, oracle session
CREATE TABLE ora_a2 AS SELECT 1 AS rowid;               -- CTAS, oracle session
CREATE TABLE ora_a3 (a int);
ALTER TABLE ora_a3 ADD COLUMN rowid int;                -- ALTER TABLE ADD COLUMN, oracle session
SET ivorysql.compatible_mode TO pg;
CREATE TABLE ora_a4 (rowid int, a int);                 -- CREATE TABLE, pg session
CREATE TABLE ora_a5 AS SELECT 1 AS rowid;               -- CTAS, pg session
CREATE TABLE ora_a6 (a int);
ALTER TABLE ora_a6 ADD COLUMN rowid int;                -- ALTER TABLE ADD COLUMN, pg session
SET ivorysql.compatible_mode TO oracle;
SELECT relname, relhasrowid, relnatts FROM pg_class WHERE relname IN ('ora_a1','ora_a2','ora_a3','ora_a4','ora_a5','ora_a6') ORDER BY relname;
INSERT INTO ora_a2 VALUES (5);
INSERT INTO ora_a5 VALUES (6);
SELECT rowid AS a2_rowid FROM ora_a2;
SELECT rowid AS a5_rowid FROM ora_a5;

-- B ------------------------------------------------------------------
SELECT count(*) AS initdb_range_funcs FROM pg_proc WHERE oid >= 12000 AND oid < 16384;
SELECT oid, proname FROM pg_proc WHERE oid >= 12000 AND oid < 16384 AND pronargs = 1 AND prokind = 'f' ORDER BY oid LIMIT 3;
SET ivorysql.compatible_mode TO pg;
CREATE TABLE ora_b1 (a int, b int GENERATED ALWAYS AS (a + 1) VIRTUAL);
SET ivorysql.compatible_mode TO oracle;
CREATE TABLE ora_b2 (a int, b int GENERATED ALWAYS AS (a + 1) VIRTUAL);
SELECT relname, attname, attgenerated FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid WHERE c.relname IN ('ora_b1','ora_b2') AND a.attnum > 0 ORDER BY relname, attnum;

-- C ------------------------------------------------------------------
SET ivorysql.compatible_mode TO oracle;
CREATE OR REPLACE FUNCTION ora_c1(a IN int, b OUT int) RETURN int IS
BEGIN b := a + 1; RETURN a; END;
/
SELECT ora_c1(1) AS c_oracle_call_without_out;
SET ivorysql.compatible_mode TO pg;
SELECT ora_c1(1) AS c_pg_call_without_out;
SELECT ora_c1(1, 2) AS c_pg_call_with_out;
SELECT ora_c1(1) AS c_oracle_call_again;

-- D ------------------------------------------------------------------
SET ivorysql.compatible_mode TO oracle;
SELECT current_schemas(true) AS oracle_implicit_path;
SET ivorysql.compatible_mode TO pg;
SELECT current_schemas(true) AS pg_implicit_path;

-- E ------------------------------------------------------------------
SET ivorysql.compatible_mode TO oracle;
CREATE TABLE ora_e1 (a int, b int);
INSERT INTO ora_e1 VALUES (1, 2);
CREATE OR REPLACE FUNCTION ora_e1f(p IN ora_e1%ROWTYPE) RETURN int IS
BEGIN RETURN p.a; END;
/
SELECT ora_e1f(t) AS e_oracle_call FROM ora_e1 t;
SELECT d.deptype, count(*) AS dep_rows FROM pg_depend d
  WHERE d.classid = 'pg_proc'::regclass
    AND d.objid = (SELECT oid FROM pg_proc WHERE proname = 'ora_e1f')
  GROUP BY d.deptype ORDER BY d.deptype;
DROP TABLE ora_e1;
SELECT prostatus AS e_prostatus_after_drop, pg_get_function_arguments(oid) AS e_args_after_drop FROM pg_proc WHERE proname = 'ora_e1f';
SELECT proname, proargtypes::text AS e_proargtypes_after_drop FROM pg_proc WHERE proname = 'ora_e1f';
SELECT p.proname, t.oid AS resolved_type FROM pg_proc p
  CROSS JOIN LATERAL unnest(string_to_array(p.proargtypes::text, ' ')::oid[]) AS t(oid)
  WHERE p.proname = 'ora_e1f';
SELECT count(*) AS e_dangling_type_refs FROM pg_proc p
  CROSS JOIN LATERAL unnest(string_to_array(p.proargtypes::text, ' ')::oid[]) AS t(oid)
  WHERE p.proname = 'ora_e1f' AND NOT EXISTS (SELECT 1 FROM pg_type ty WHERE ty.oid = t.oid);

-- E control: same shape of function created by a PG-mode session
SET ivorysql.compatible_mode TO pg;
CREATE TABLE ora_e2 (a int, b int);
INSERT INTO ora_e2 VALUES (1, 2);
CREATE OR REPLACE FUNCTION ora_e2f(p ora_e2) RETURNS int LANGUAGE plisql AS $x$
BEGIN RETURN p.a; END; $x$;
SELECT ora_e2f(t) AS e_control_call FROM ora_e2 t;
DROP TABLE ora_e2;
SELECT prostatus AS e_control_prostatus FROM pg_proc WHERE proname = 'ora_e2f';

-- cleanup
SET ivorysql.compatible_mode TO oracle;
DROP TABLE ora_a1;
DROP TABLE ora_a2;
DROP TABLE ora_a3;
DROP TABLE ora_a4;
DROP TABLE ora_a5;
DROP TABLE ora_a6;
DROP TABLE ora_b1;
DROP TABLE ora_b2;
DROP FUNCTION ora_c1(int);
DROP FUNCTION ora_e1f(ora_e1);
DROP FUNCTION ora_e2f(ora_e2);