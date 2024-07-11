CREATE OR REPLACE FUNCTION catbench.get_function_id
(
    benchmark_name text,
    function_name text
)
RETURNS bigint
LANGUAGE SQL
STABLE
BEGIN ATOMIC
    SELECT catbench.functions.id
    FROM catbench.benchmarks
    JOIN catbench.functions
      ON catbench.functions.benchmark_id = catbench.benchmarks.id
    WHERE catbench.benchmarks.name = get_function_id.benchmark_name
      AND catbench.functions.name = get_function_id.function_name;
END;
