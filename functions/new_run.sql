CREATE OR REPLACE FUNCTION catbench.new_run
(
    benchmark_name text,
    host_id uuid,
    commit_hash text
)
RETURNS uuid
LANGUAGE SQL
BEGIN ATOMIC
    INSERT INTO catbench.runs
        (benchmark_id, host_id, commit_id)
    VALUES
        (
            catbench.get_benchmark_id(benchmark_name),
            host_id,
            catbench.get_commit_id(commit_hash)
        )
    RETURNING id;
END;
