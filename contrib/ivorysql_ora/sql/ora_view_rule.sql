--
-- Views, rules and ALTER TABLE in Oracle-compatible mode
--
-- When a plain view depends on a column whose type is changed, IvorySQL
-- invalidates the view (turns it into a force view) instead of refusing the
-- ALTER, and the view is expected to keep working.  This test walks the
-- neighbouring cases: a view built on top of that view, a second type change
-- on the same column, re-validating the view with CREATE OR REPLACE, and
-- renaming the view afterwards.
--
SET ivorysql.compatible_mode TO ORACLE;
SHOW ivorysql.compatible_mode;

CREATE TABLE ora_view_t (a char(20), b int);
INSERT INTO ora_view_t VALUES ('one', 1);
CREATE VIEW ora_view_v AS SELECT a, b FROM ora_view_t;
CREATE VIEW ora_view_v2 AS SELECT a FROM ora_view_v;

-- ora_view_v depends on column a: the type change invalidates that view.
ALTER TABLE ora_view_t ALTER COLUMN a TYPE char(25);
SELECT * FROM ora_view_v;
SELECT * FROM ora_view_v2;
SELECT relname, relnatts, relhasrules FROM pg_class
  WHERE relname IN ('ora_view_v', 'ora_view_v2') ORDER BY relname;
SELECT relname, count(*) AS force_rows FROM pg_force_view f JOIN pg_class c ON c.oid = f.fvoid
  WHERE c.relname IN ('ora_view_v', 'ora_view_v2') GROUP BY relname ORDER BY relname;
SELECT pg_get_viewdef('ora_view_v'::regclass);

-- A second type change on the same column.
ALTER TABLE ora_view_t ALTER COLUMN a TYPE char(30);
SELECT * FROM ora_view_v;
SELECT * FROM ora_view_v2;

-- CREATE OR REPLACE turns the invalidated view back into a normal view.
CREATE OR REPLACE VIEW ora_view_v AS SELECT a, b FROM ora_view_t;
SELECT relname, relnatts, relhasrules FROM pg_class WHERE relname = 'ora_view_v';
SELECT count(*) AS force_rows FROM pg_force_view f JOIN pg_class c ON c.oid = f.fvoid
  WHERE c.relname = 'ora_view_v';
SELECT * FROM ora_view_v;
SELECT * FROM ora_view_v2;

-- Renaming the re-validated view.
ALTER VIEW ora_view_v RENAME TO ora_view_v_renamed;
SELECT pg_get_viewdef('ora_view_v_renamed'::regclass);
SELECT * FROM ora_view_v2;

DROP VIEW ora_view_v2;
DROP VIEW ora_view_v_renamed;
DROP TABLE ora_view_t;