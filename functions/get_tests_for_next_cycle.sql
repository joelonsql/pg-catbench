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
    count_results AS
    (
        SELECT
            catbench.results.benchmark_id,
            catbench.results.commit_id,
            catbench.results.test_id,
            COUNT(*)
        FROM catbench.results
        WHERE catbench.results.system_config_id = get_tests_for_next_cycle.system_config_id
        GROUP BY
            catbench.results.benchmark_id,
            catbench.results.commit_id,
            catbench.results.test_id
    ),
    change_commits AS
    (
        SELECT
            catbench.commits.id AS commit_id,
            catbench.commits.commit_hash,
            catbench.commits.parent_hash,
            benchmarks.id AS benchmark_id,
            benchmarks.name AS benchmark_name
        FROM catbench.commits
        JOIN catbench.benchmarks ON EXISTS
        (
            SELECT 1
            FROM catbench.benchmark_files
            JOIN catbench.commit_files
              ON catbench.commit_files.file_id = catbench.benchmark_files.file_id
            WHERE catbench.benchmark_files.benchmark_id = catbench.benchmarks.id
              AND catbench.commit_files.commit_id = catbench.commits.id
        )
        --
        -- Benchmark all commits since REL_12_BETA1
        --
        AND catbench.commits.id >
        (
            SELECT REL_12_BETA1.id
            FROM catbench.commits AS REL_12_BETA1
            WHERE REL_12_BETA1.commit_hash = 'a240570b1e3802d1e82da08a9d72abeade370249'
        )
    ),
    with_parents AS
    (
        SELECT
            change_commits.commit_id,
            change_commits.commit_hash,
            change_commits.benchmark_id,
            change_commits.benchmark_name
        FROM change_commits
        UNION
        SELECT
            parent_commit.id,
            parent_commit.commit_hash,
            change_commits.benchmark_id,
            change_commits.benchmark_name
        FROM change_commits
        JOIN catbench.commits AS parent_commit
          ON parent_commit.commit_hash = change_commits.parent_hash
    ),
    generate_benchmark_commit_permutations AS
    (
        SELECT
            with_parents.commit_id,
            with_parents.commit_hash,
            with_parents.benchmark_id,
            with_parents.benchmark_name,
            catbench.tests.id AS test_id
        FROM with_parents
        JOIN catbench.functions
        ON catbench.functions.benchmark_id = with_parents.benchmark_id
        JOIN catbench.tests
        ON catbench.tests.function_id = catbench.functions.id
    ),
    count_benchmark_results_for_system_config AS
    (
        SELECT
            g.commit_id,
            g.commit_hash,
            g.benchmark_id,
            g.benchmark_name,
            g.test_id,
            COALESCE(count_results.count,0) AS count
        FROM generate_benchmark_commit_permutations AS g
        LEFT JOIN count_results
               ON count_results.benchmark_id = g.benchmark_id
              AND count_results.commit_id = g.commit_id
              AND count_results.test_id = g.test_id
    ),
    min_count AS
    (
        SELECT COALESCE(MIN(count),0) AS count FROM count_benchmark_results_for_system_config
    )
    SELECT
        c.commit_id,
        c.commit_hash,
        c.benchmark_id,
        c.benchmark_name,
        c.test_id,
        c.count
    FROM count_benchmark_results_for_system_config AS c
    WHERE c.count = (SELECT count FROM min_count)
      AND c.count < get_tests_for_next_cycle.max_target_result_count
    ORDER BY c.commit_id, random();
END;
