CREATE OR REPLACE FUNCTION catbench.insert_result
(
    execution_time float8,
    benchmark_id bigint,
    system_config_id uuid,
    commit_id bigint,
    test_id bigint
)
RETURNS uuid
LANGUAGE SQL
BEGIN ATOMIC
    INSERT INTO catbench.results
        (execution_time, benchmark_id, system_config_id, commit_id, test_id)
    VALUES
        (execution_time, benchmark_id, system_config_id, commit_id, test_id)
    RETURNING id;
END;
