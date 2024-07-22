CREATE OR REPLACE FUNCTION catbench.insert_result
(
    execution_time float8,
    benchmark_id bigint,
    system_config_id uuid,
    commit_id bigint,
    test_id bigint,
    benchmark_duration interval
)
RETURNS uuid
LANGUAGE SQL
BEGIN ATOMIC
    INSERT INTO catbench.results
        (execution_time, benchmark_id, system_config_id, commit_id, test_id, benchmark_duration)
    VALUES
        (execution_time, benchmark_id, system_config_id, commit_id, test_id, benchmark_duration)
    RETURNING id;
END;
