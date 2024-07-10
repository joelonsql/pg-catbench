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

all: catbench--0.1.sql

SQL_SRC = \
	complain_header.sql \
	tables/benchmarks.sql \
	tables/file_mappings.sql \
	tables/function_mappings.sql \
	functions/new_benchmark.sql \
	functions/get_benchmark.sql \
	functions/new_file_mapping.sql \
	functions/new_function_mapping.sql \
	benchmarks/numeric.sql

catbench--0.1.sql: $(SQL_SRC)
	cat $^ > $@
