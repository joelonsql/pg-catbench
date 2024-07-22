CREATE OR REPLACE FUNCTION catbench.count_benchmark_results_for_system_config
(
    system_config_id uuid
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
        g.commit_id,
        g.commit_hash,
        g.benchmark_id,
        g.benchmark_name,
        g.test_id,
        (
            SELECT COUNT(*) FROM catbench.results
            WHERE catbench.results.commit_id        = g.commit_id
              AND catbench.results.benchmark_id     = g.benchmark_id
              AND catbench.results.test_id          = g.test_id
              AND catbench.results.system_config_id = count_benchmark_results_for_system_config.system_config_id
        )
    FROM catbench.generate_benchmark_commit_permutations() AS g;
END;
