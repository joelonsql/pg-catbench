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
    SELECT
        c.commit_id,
        c.commit_hash,
        c.benchmark_id,
        c.benchmark_name,
        c.test_id,
        c.count_results
    FROM catbench.count_benchmark_results_for_system_config(system_config_id) AS c
    WHERE c.count_results < get_tests_for_next_cycle.max_target_result_count;
END;
