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
	tables/functions.sql \
	tables/tests.sql \
	tables/system_configs.sql \
	tables/commits.sql \
	tables/files.sql \
	tables/commit_files.sql \
	tables/benchmark_files.sql \
	tables/compilations.sql \
	tables/results.sql \
	functions/register_system_config.sql \
	functions/new_benchmark.sql \
	functions/generate_benchmark_commit_permutations.sql \
	functions/count_benchmark_results_for_system_config.sql \
	functions/get_tests_for_next_cycle.sql \
	functions/get_benchmark_id.sql \
	functions/get_benchmark_test_ids.sql \
	functions/get_function_id.sql \
	functions/get_or_insert_file.sql \
	functions/new_benchmark_file.sql \
	functions/new_function.sql \
	functions/get_commit_id.sql \
	functions/generate_test.sql \
	functions/insert_result.sql \
	functions/set_executable_hash.sql \
	functions/get_executable_hash.sql \
	procedures/merge_new_commits.sql \
	views/vresults.sql \
	views/vreport.sql \
	views/vcommits.sql \
	benchmarks/numeric.sql

catbench--0.1.sql: $(SQL_SRC)
	cat $^ > $@

docs/data-model.svg: docs/data-model.dot
	dot -Tsvg docs/data-model.dot -o docs/data-model.svg
