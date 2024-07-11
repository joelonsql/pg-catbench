CREATE OR REPLACE FUNCTION catbench.new_run
(
    benchmark_name text,
    host_id uuid
)
RETURNS uuid
LANGUAGE SQL
BEGIN ATOMIC
    INSERT INTO catbench.runs
        (benchmark_id, host_id)
    VALUES
        (catbench.get_benchmark_id(benchmark_name), host_id)
    RETURNING id;
END;
