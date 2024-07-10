CREATE FUNCTION catbench.get_benchmark(name text)
RETURNS bigint
LANGUAGE SQL
BEGIN ATOMIC
    SELECT catbench.benchmarks.id
    FROM catbench.benchmarks
    WHERE catbench.benchmarks.name = get_benchmark.name;
END;
