CREATE OR REPLACE FUNCTION catbench.new_run
(
    benchmark_name text,
    system_config_id uuid,
    commit_hash text
)
RETURNS uuid
LANGUAGE SQL
BEGIN ATOMIC
    INSERT INTO catbench.runs
        (benchmark_id, system_config_id, commit_id)
    VALUES
        (
            catbench.get_benchmark_id(benchmark_name),
            system_config_id,
            catbench.get_commit_id(commit_hash)
        )
    RETURNING id;
END;
