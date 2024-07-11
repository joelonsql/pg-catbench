EXTENSION = catbench
DATA = \
	catbench--0.1.sql

REGRESS = \
	catbench

EXTRA_CLEAN = catbench--0.1.sql

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

REGRESS_OPTS = --inputdir=tests --outputdir=tests

all: catbench--0.1.sql docs/data-model.svg

SQL_SRC = \
	complain_header.sql \
	tables/benchmarks.sql \
	tables/file_mappings.sql \
	tables/functions.sql \
	tables/tests.sql \
	tables/hosts.sql \
	tables/runs.sql \
	tables/results.sql \
	functions/register_host.sql \
	functions/new_benchmark.sql \
	functions/get_benchmark_id.sql \
	functions/get_benchmark_test_ids.sql \
	functions/get_function_id.sql \
	functions/new_file_mapping.sql \
	functions/new_function.sql \
	functions/new_run.sql \
	functions/mark_run_as_finished.sql \
	procedures/run_test.sql \
	benchmarks/numeric.sql

catbench--0.1.sql: $(SQL_SRC)
	cat $^ > $@

docs/data-model.svg: docs/data-model.dot
	dot -Tsvg docs/data-model.dot -o docs/data-model.svg
