--
-- PROBE ONLY (characterisation run, not evidence): force-view lifecycle
--
SET ivorysql.compatible_mode TO ORACLE;
SHOW ivorysql.compatible_mode;

-- A: does a force view's pg_force_view row survive DROP VIEW issued in pg mode?
CREATE TABLE ora_fv_t (a char(20));
INSERT INTO ora_fv_t VALUES ('one');
CREATE VIEW ora_fv_v AS SELECT a FROM ora_fv_t;
ALTER TABLE ora_fv_t ALTER COLUMN a TYPE char(25);
SELECT count(*) AS force_rows_after_alter FROM pg_force_view;
SELECT relname, relnatts, relhasrules FROM pg_class WHERE relname = 'ora_fv_v';
SET ivorysql.compatible_mode TO PG;
DROP VIEW ora_fv_v;
SELECT count(*) AS force_rows_after_drop_in_pg_mode FROM pg_force_view;

-- control: identical sequence, but DROP in oracle mode
SET ivorysql.compatible_mode TO ORACLE;
CREATE VIEW ora_fv_v2 AS SELECT a FROM ora_fv_t;
ALTER TABLE ora_fv_t ALTER COLUMN a TYPE char(30);
SELECT count(*) AS force_rows_after_alter2 FROM pg_force_view;
DROP VIEW ora_fv_v2;
SELECT count(*) AS force_rows_after_drop_in_oracle_mode FROM pg_force_view;

-- B: rename an invalid (force) view before it is ever recompiled
CREATE VIEW ora_fv_v3 AS SELECT a FROM ora_fv_t;
ALTER TABLE ora_fv_t ALTER COLUMN a TYPE char(35);
SELECT count(*) AS force_rows_after_alter3 FROM pg_force_view;
SELECT source FROM pg_force_view f JOIN pg_class c ON c.oid = f.fvoid WHERE c.relname = 'ora_fv_v3';
ALTER VIEW ora_fv_v3 RENAME TO ora_fv_v4;
SELECT relname FROM pg_class WHERE relname IN ('ora_fv_v3', 'ora_fv_v4') ORDER BY relname;
SELECT source FROM pg_force_view f JOIN pg_class c ON c.oid = f.fvoid WHERE c.relname = 'ora_fv_v4';
SELECT * FROM ora_fv_v4;
SELECT count(*) AS force_rows_after_recompile FROM pg_force_view;
DROP VIEW ora_fv_v4;
DROP TABLE ora_fv_t;