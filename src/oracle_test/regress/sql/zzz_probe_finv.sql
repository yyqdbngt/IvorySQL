--
-- PROBE ONLY (characterisation run, not evidence): is the invalidation of
-- dependent plisql functions after a relation change decided by the compatible
-- mode of the session that performs the change?
--
-- s0: after create (check_function_bodies on)
-- s1: ALTER TABLE ... ALTER COLUMN TYPE  done by a PG-mode session   (ungated code path)
-- s2: ALTER TABLE ... RENAME COLUMN      done by an ORACLE-mode session
-- s3: ALTER TABLE ... RENAME COLUMN      done by a PG-mode session
-- s4: ALTER TABLE ... RENAME TO          done by an ORACLE-mode session
-- s5: ALTER TABLE ... RENAME TO          done by a PG-mode session
--
CREATE TABLE ora_finv_t0 (a int, b int);
INSERT INTO ora_finv_t0 VALUES (1, 2);

CREATE OR REPLACE FUNCTION ora_finv_f0(p IN int) RETURN int IS
  v int;
BEGIN
  SELECT b INTO v FROM ora_finv_t0 WHERE a = p;
  RETURN v;
END;
/
SELECT ora_finv_f0(1) AS call_s0;
SELECT prostatus AS s0_after_create FROM pg_proc WHERE proname = 'ora_finv_f0';

-- s1: type change, PG-mode session
SET ivorysql.compatible_mode TO pg;
ALTER TABLE ora_finv_t0 ALTER COLUMN b TYPE bigint;
SET ivorysql.compatible_mode TO oracle;
SELECT prostatus AS s1_after_pg_type_change FROM pg_proc WHERE proname = 'ora_finv_f0';

-- s2: rename column, ORACLE-mode session
CREATE TABLE ora_finv_t2 (a int, b int);
INSERT INTO ora_finv_t2 VALUES (1, 2);
CREATE OR REPLACE FUNCTION ora_finv_f2(p IN int) RETURN int IS
  v int;
BEGIN
  SELECT b INTO v FROM ora_finv_t2 WHERE a = p;
  RETURN v;
END;
/
SELECT ora_finv_f2(1) AS call_s2;
ALTER TABLE ora_finv_t2 RENAME COLUMN b TO b2;
SELECT prostatus AS s2_after_ora_rename_column FROM pg_proc WHERE proname = 'ora_finv_f2';
SELECT ora_finv_f2(1) AS call_s2_again;

-- s3: rename column, PG-mode session
CREATE TABLE ora_finv_t3 (a int, b int);
INSERT INTO ora_finv_t3 VALUES (1, 2);
CREATE OR REPLACE FUNCTION ora_finv_f3(p IN int) RETURN int IS
  v int;
BEGIN
  SELECT b INTO v FROM ora_finv_t3 WHERE a = p;
  RETURN v;
END;
/
SELECT ora_finv_f3(1) AS call_s3;
SET ivorysql.compatible_mode TO pg;
ALTER TABLE ora_finv_t3 RENAME COLUMN b TO b3;
SET ivorysql.compatible_mode TO oracle;
SELECT prostatus AS s3_after_pg_rename_column FROM pg_proc WHERE proname = 'ora_finv_f3';
SELECT ora_finv_f3(1) AS call_s3_again;

-- s4: rename table, ORACLE-mode session
CREATE TABLE ora_finv_t4 (a int, b int);
INSERT INTO ora_finv_t4 VALUES (1, 2);
CREATE OR REPLACE FUNCTION ora_finv_f4(p IN int) RETURN int IS
  v int;
BEGIN
  SELECT b INTO v FROM ora_finv_t4 WHERE a = p;
  RETURN v;
END;
/
SELECT ora_finv_f4(1) AS call_s4;
ALTER TABLE ora_finv_t4 RENAME TO ora_finv_t4x;
SELECT prostatus AS s4_after_ora_rename_table FROM pg_proc WHERE proname = 'ora_finv_f4';
SELECT ora_finv_f4(1) AS call_s4_again;

-- s5: rename table, PG-mode session
CREATE TABLE ora_finv_t5 (a int, b int);
INSERT INTO ora_finv_t5 VALUES (1, 2);
CREATE OR REPLACE FUNCTION ora_finv_f5(p IN int) RETURN int IS
  v int;
BEGIN
  SELECT b INTO v FROM ora_finv_t5 WHERE a = p;
  RETURN v;
END;
/
SELECT ora_finv_f5(1) AS call_s5;
SET ivorysql.compatible_mode TO pg;
ALTER TABLE ora_finv_t5 RENAME TO ora_finv_t5x;
SET ivorysql.compatible_mode TO oracle;
SELECT prostatus AS s5_after_pg_rename_table FROM pg_proc WHERE proname = 'ora_finv_f5';
SELECT ora_finv_f5(1) AS call_s5_again;

-- dependency bookkeeping left behind (DEPENDENCY_TYPE rows of plisql functions)
SELECT d.deptype, count(*) AS dep_rows FROM pg_depend d
  WHERE d.classid = 'pg_proc'::regclass
  GROUP BY d.deptype ORDER BY d.deptype;

SET ivorysql.compatible_mode TO pg;
DROP TABLE ora_finv_t0;
DROP TABLE ora_finv_t2;
DROP TABLE ora_finv_t3;
DROP TABLE ora_finv_t4x;
DROP TABLE ora_finv_t5x;
SET ivorysql.compatible_mode TO oracle;
DROP FUNCTION ora_finv_f0(int);
DROP FUNCTION ora_finv_f2(int);
DROP FUNCTION ora_finv_f3(int);
DROP FUNCTION ora_finv_f4(int);
DROP FUNCTION ora_finv_f5(int);