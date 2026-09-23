--
-- PROBE ONLY (characterisation run, not evidence) #3
-- (1) index.c/plancat.c: an index disabled by an ORACLE-mode session -- is a plain
--     REINDEX issued by a PG-mode session enough to recover it, as the in-tree
--     comment claims ("a completed non-concurrent rebuild always clears UNUSABLE")?
-- (2) informational: the rowid name gate (heap.c / parse_utilcmd.c), a table with a
--     rowid column created in PG mode and then used from an ORACLE-mode session.
--
CREATE TABLE ora_iu_t (a int, b int);
CREATE UNIQUE INDEX ora_iu_i ON ora_iu_t (a);
ALTER INDEX ora_iu_i UNUSABLE;
SELECT indisunusable AS after_unusable FROM pg_index WHERE indexrelid = 'ora_iu_i'::regclass;
INSERT INTO ora_iu_t VALUES (1, 1);
INSERT INTO ora_iu_t VALUES (1, 2);
SELECT count(*) AS rows_while_unusable FROM ora_iu_t;
SET ivorysql.compatible_mode TO pg;
REINDEX INDEX ora_iu_i;
SELECT indisunusable AS after_pg_reindex FROM pg_index WHERE indexrelid = 'ora_iu_i'::regclass;
REINDEX INDEX ora_iu_i;
SELECT indisunusable AS after_second_pg_reindex FROM pg_index WHERE indexrelid = 'ora_iu_i'::regclass;
SET ivorysql.compatible_mode TO oracle;
SELECT indisunusable AS back_in_oracle_mode FROM pg_index WHERE indexrelid = 'ora_iu_i'::regclass;
INSERT INTO ora_iu_t VALUES (1, 3);

SET ivorysql.compatible_mode TO pg;
CREATE TABLE ora_rowid_t (rowid int, a int);
INSERT INTO ora_rowid_t VALUES (7, 1);
SELECT rowid AS pg_mode_rowid FROM ora_rowid_t;
SET ivorysql.compatible_mode TO oracle;
SELECT rowid AS ora_mode_rowid FROM ora_rowid_t;
SELECT a AS ora_mode_col_a FROM ora_rowid_t;
SELECT rowid AS qualified_rowid, a FROM ora_rowid_t t;
SET ivorysql.compatible_mode TO pg;
DROP TABLE ora_rowid_t;
DROP TABLE ora_iu_t;