CREATE OR REPLACE FUNCTION catbench.get_benchmark_id(name text)
RETURNS bigint
LANGUAGE SQL
STABLE
BEGIN ATOMIC
    SELECT catbench.benchmarks.id
    FROM catbench.benchmarks
    WHERE catbench.benchmarks.name = get_benchmark_id.name;
END;
