CREATE OR REPLACE FUNCTION catbench.get_benchmark_test_ids(benchmark_name text)
RETURNS TABLE(id bigint)
LANGUAGE SQL
BEGIN ATOMIC
    SELECT
        catbench.tests.id
    FROM catbench.benchmarks
    JOIN catbench.functions
      ON catbench.functions.benchmark_id = catbench.benchmarks.id
    JOIN catbench.tests
      ON catbench.tests.function_id = catbench.functions.id
    WHERE catbench.benchmarks.name = get_benchmark_test_ids.benchmark_name
    -- return in pseudo-random deterministic order
    ORDER BY hashint8(catbench.tests.id);
END;
