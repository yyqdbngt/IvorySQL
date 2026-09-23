--
-- PROBE ONLY (characterisation run, not evidence) #2: the invalidation machinery
-- is scoped to %TYPE/%ROWTYPE dependencies.  Does the compatible mode of the
-- session that changes the relation decide the outcome for such a function?
--
-- A: ALTER COLUMN TYPE, PG-mode session      B: ALTER COLUMN TYPE, ORACLE-mode session
-- C: RENAME COLUMN,    PG-mode session      D: RENAME COLUMN,    ORACLE-mode session
--
CREATE TABLE ora_pt1 (a int, b int);
CREATE OR REPLACE FUNCTION ora_pf1(p IN ora_pt1.b%TYPE) RETURN ora_pt1.b%TYPE IS
BEGIN
  RETURN p;
END;
/
SELECT ora_pf1(1) AS a_call_before;
SELECT prostatus AS a_prostatus, pg_get_function_result(oid) AS a_result, pg_get_function_arguments(oid) AS a_args FROM pg_proc WHERE proname = 'ora_pf1';
SELECT count(*) AS a_type_dep_rows FROM pg_depend WHERE classid = 'pg_proc'::regclass AND deptype = 't';
SET ivorysql.compatible_mode TO pg;
ALTER TABLE ora_pt1 ALTER COLUMN b TYPE bigint;
SET ivorysql.compatible_mode TO oracle;
SELECT prostatus AS a_prostatus_after, pg_get_function_result(oid) AS a_result_after, pg_get_function_arguments(oid) AS a_args_after FROM pg_proc WHERE proname = 'ora_pf1';
SELECT count(*) AS a_type_dep_rows_after FROM pg_depend WHERE classid = 'pg_proc'::regclass AND deptype = 't';
SELECT ora_pf1(2::bigint) AS a_call_newtype;
SELECT ora_pf1(3) AS a_call_int;

CREATE TABLE ora_pt2 (a int, b int);
CREATE OR REPLACE FUNCTION ora_pf2(p IN ora_pt2.b%TYPE) RETURN ora_pt2.b%TYPE IS
BEGIN
  RETURN p;
END;
/
SELECT ora_pf2(1) AS b_call_before;
ALTER TABLE ora_pt2 ALTER COLUMN b TYPE bigint;
SELECT prostatus AS b_prostatus_after, pg_get_function_result(oid) AS b_result_after, pg_get_function_arguments(oid) AS b_args_after FROM pg_proc WHERE proname = 'ora_pf2';
SELECT count(*) AS b_type_dep_rows_after FROM pg_depend WHERE classid = 'pg_proc'::regclass AND deptype = 't';
SELECT ora_pf2(2::bigint) AS b_call_newtype;
SELECT ora_pf2(3) AS b_call_int;

CREATE TABLE ora_pt3 (a int, b int);
CREATE OR REPLACE FUNCTION ora_pf3(p IN ora_pt3.b%TYPE) RETURN ora_pt3.b%TYPE IS
BEGIN
  RETURN p;
END;
/
SELECT ora_pf3(1) AS c_call_before;
SELECT prostatus AS c_prostatus, pg_get_function_arguments(oid) AS c_args FROM pg_proc WHERE proname = 'ora_pf3';
SET ivorysql.compatible_mode TO pg;
ALTER TABLE ora_pt3 RENAME COLUMN b TO b3;
SET ivorysql.compatible_mode TO oracle;
SELECT prostatus AS c_prostatus_after, pg_get_function_arguments(oid) AS c_args_after FROM pg_proc WHERE proname = 'ora_pf3';
SELECT ora_pf3(3) AS c_call_after;

CREATE TABLE ora_pt4 (a int, b int);
CREATE OR REPLACE FUNCTION ora_pf4(p IN ora_pt4.b%TYPE) RETURN ora_pt4.b%TYPE IS
BEGIN
  RETURN p;
END;
/
SELECT ora_pf4(1) AS d_call_before;
ALTER TABLE ora_pt4 RENAME COLUMN b TO b4;
SELECT prostatus AS d_prostatus_after, pg_get_function_arguments(oid) AS d_args_after FROM pg_proc WHERE proname = 'ora_pf4';
SELECT ora_pf4(4) AS d_call_after;

DROP TABLE ora_pt1;
DROP TABLE ora_pt2;
DROP TABLE ora_pt3;
DROP TABLE ora_pt4;
DROP FUNCTION ora_pf1(int);
DROP FUNCTION ora_pf2(int);
DROP FUNCTION ora_pf3(int);
DROP FUNCTION ora_pf4(int);