CREATE OR REPLACE FUNCTION catbench.generate_benchmark_commit_permutations()
RETURNS TABLE
(
    commit_id bigint,
    commit_hash text,
    benchmark_id bigint,
    benchmark_name text,
    test_id bigint
)
LANGUAGE SQL
BEGIN ATOMIC
    WITH
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
    )
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
    ORDER BY with_parents.commit_id, random();
END;
