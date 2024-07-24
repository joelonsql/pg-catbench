CREATE OR REPLACE FUNCTION catbench.get_tests_for_next_cycle
(
    system_config_id uuid,
    max_target_result_count bigint
)
RETURNS TABLE
(
    commit_id bigint,
    commit_hash text,
    benchmark_id bigint,
    benchmark_name text,
    test_id bigint,
    count_results bigint
)
LANGUAGE SQL
BEGIN ATOMIC
    WITH
    q AS
    (
        SELECT
            c.commit_id,
            c.commit_hash,
            c.benchmark_id,
            c.benchmark_name,
            c.test_id,
            c.count_results,
            MIN(c.count_results) OVER ()
        FROM catbench.count_benchmark_results_for_system_config(system_config_id) AS c
    )
    SELECT
        q.commit_id,
        q.commit_hash,
        q.benchmark_id,
        q.benchmark_name,
        q.test_id,
        q.count_results
    FROM q
    WHERE q.count_results = q.MIN;
END;
