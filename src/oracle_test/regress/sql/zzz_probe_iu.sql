--
-- PROBE ONLY (characterisation run, not evidence) #3b
-- index.c / plancat.c: an index disabled by an ORACLE-mode session.
-- (a) failed rebuild must not clear the flag; (b) successful rebuild from a PG-mode
--     session must clear it ("a completed non-concurrent rebuild always clears UNUSABLE").
--
CREATE TABLE ora_iu_t (a int, b int);
CREATE UNIQUE INDEX ora_iu_i ON ora_iu_t (a);
ALTER INDEX ora_iu_i UNUSABLE;
SELECT indisunusable AS a_after_unusable FROM pg_index WHERE indexrelid = 'ora_iu_i'::regclass;
INSERT INTO ora_iu_t VALUES (1, 1);
INSERT INTO ora_iu_t VALUES (1, 2);
SET ivorysql.compatible_mode TO pg;
REINDEX INDEX ora_iu_i;
SELECT indisunusable AS a_after_failed_pg_reindex FROM pg_index WHERE indexrelid = 'ora_iu_i'::regclass;

CREATE TABLE ora_iu2_t (a int);
CREATE UNIQUE INDEX ora_iu2_i ON ora_iu2_t (a);
INSERT INTO ora_iu2_t VALUES (1);
SET ivorysql.compatible_mode TO oracle;
ALTER INDEX ora_iu2_i UNUSABLE;
SELECT indisunusable AS b_after_unusable FROM pg_index WHERE indexrelid = 'ora_iu2_i'::regclass;
SET ivorysql.compatible_mode TO pg;
REINDEX INDEX ora_iu2_i;
SELECT indisunusable AS b_after_pg_reindex FROM pg_index WHERE indexrelid = 'ora_iu2_i'::regclass;
INSERT INTO ora_iu2_t VALUES (1);
INSERT INTO ora_iu2_t VALUES (2);
SELECT count(*) AS b_rows FROM ora_iu2_t;
SET ivorysql.compatible_mode TO oracle;
SELECT indisunusable AS b_back_in_oracle_mode FROM pg_index WHERE indexrelid = 'ora_iu2_i'::regclass;
DROP TABLE ora_iu2_t;
DROP TABLE ora_iu_t;