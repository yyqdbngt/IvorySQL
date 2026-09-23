--
-- PROBE ONLY (characterisation, not evidence): a standalone composite type
-- (CREATE TYPE ... AS) used in a PL/iSQL signature.  Is the ordinary dependency
-- on the type recorded in Oracle mode, and does DROP TYPE then corrupt pg_proc?
--
SET ivorysql.compatible_mode TO oracle;

-- 1: direct composite parameter type
CREATE TYPE ora_ct1 AS (a int, b int);
CREATE OR REPLACE FUNCTION ora_ctf1(p IN ora_ct1) RETURN int IS
BEGIN RETURN p.a; END;
/
SELECT ora_ctf1(ROW(1,2)::ora_ct1) AS c1_call;
SELECT t.oid AS c1_type_oid, t.typtype, t.typrelid, (SELECT relkind FROM pg_class WHERE oid = t.typrelid) AS c1_relkind
  FROM pg_type t WHERE t.typname = 'ora_ct1';
SELECT d.deptype, count(*) AS dep_rows FROM pg_depend d
  WHERE d.classid = 'pg_proc'::regclass AND d.objid = (SELECT oid FROM pg_proc WHERE proname = 'ora_ctf1')
  GROUP BY d.deptype ORDER BY d.deptype;
DROP TYPE ora_ct1;
SELECT proname, proargtypes::text AS c1_proargtypes_after_drop FROM pg_proc WHERE proname = 'ora_ctf1';
SELECT count(*) AS c1_dangling_type_refs FROM pg_proc p
  CROSS JOIN LATERAL unnest(string_to_array(p.proargtypes::text, ' ')::oid[]) AS t(oid)
  WHERE p.proname = 'ora_ctf1' AND NOT EXISTS (SELECT 1 FROM pg_type ty WHERE ty.oid = t.oid);
SELECT pg_get_function_arguments(oid) AS c1_args FROM pg_proc WHERE proname = 'ora_ctf1';
SELECT oid::regprocedure::text AS c1_regprocedure FROM pg_proc WHERE proname = 'ora_ctf1';
CREATE TYPE ora_ct1 AS (a int, b int);
DROP FUNCTION ora_ctf1(ora_ct1);
SELECT count(*) AS c1_still_in_catalog FROM pg_proc WHERE proname = 'ora_ctf1';
DROP TYPE ora_ct1;

-- 2: %ROWTYPE syntax over a standalone composite type
CREATE TYPE ora_ct2 AS (a int);
CREATE OR REPLACE FUNCTION ora_ctf2(p IN ora_ct2%ROWTYPE) RETURN int IS
BEGIN RETURN p.a; END;
/
DROP TYPE ora_ct2;
SELECT count(*) AS c2_dangling_type_refs FROM pg_proc p
  CROSS JOIN LATERAL unnest(string_to_array(p.proargtypes::text, ' ')::oid[]) AS t(oid)
  WHERE p.proname = 'ora_ctf2' AND NOT EXISTS (SELECT 1 FROM pg_type ty WHERE ty.oid = t.oid);

-- 3: composite return type only
CREATE TYPE ora_ct3 AS (a int);
CREATE OR REPLACE FUNCTION ora_ctf3 RETURN ora_ct3 IS
BEGIN RETURN ROW(1)::ora_ct3; END;
/
DROP TYPE ora_ct3;
SELECT count(*) AS c3_dangling_rettype_refs FROM pg_proc p
  WHERE p.proname = 'ora_ctf3' AND NOT EXISTS (SELECT 1 FROM pg_type ty WHERE ty.oid = p.prorettype);
SELECT pg_get_function_result(oid) AS c3_result FROM pg_proc WHERE proname = 'ora_ctf3';

-- 4: control, same shape with plpgsql in the same server
CREATE TYPE ora_ct4 AS (a int);
CREATE FUNCTION ora_ctf4(p ora_ct4) RETURNS int LANGUAGE plpgsql AS $x$
BEGIN RETURN p.a; END; $x$;
DROP TYPE ora_ct4;
SELECT pg_get_function_arguments(oid) AS c4_args FROM pg_proc WHERE proname = 'ora_ctf4';
DROP FUNCTION ora_ctf4(ora_ct4);
DROP TYPE ora_ct4;

-- cleanup
DROP FUNCTION IF EXISTS ora_ctf1(ora_ct1);
DROP FUNCTION IF EXISTS ora_ctf2(ora_ct2);
DROP FUNCTION IF EXISTS ora_ctf3();
DROP TYPE IF EXISTS ora_ct1;
DROP TYPE IF EXISTS ora_ct2;
DROP TYPE IF EXISTS ora_ct3;