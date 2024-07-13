CREATE OR REPLACE FUNCTION catbench.get_next_benchmark_run
(
    system_config_id uuid
)
RETURNS TABLE
(
    run_id uuid,
    benchmark_name text,
    benchmark_id bigint,
    commit_hash text,
    commit_id bigint
)
LANGUAGE SQL
BEGIN ATOMIC
    WITH next_run AS
    (
        INSERT INTO catbench.runs
        (
            benchmark_id,
            system_config_id,
            commit_id
        )
        WITH
        --
        -- We need to get the previous commit ID for each commit,
        -- to compare the benchmark effect of a commit,
        -- against its immediate predecessor.
        --
        commit_history AS
        (
            SELECT
                id,
                LAG(id) OVER (ORDER BY id) AS prev_id
            FROM catbench.commits
        )
        SELECT
            catbench.benchmarks.id,
            get_next_benchmark_run.system_config_id,
            catbench.commits.id
        FROM catbench.benchmarks
        --
        -- Identify commits that changed at least one of the files
        -- associated with each benchmark.
        --
        JOIN commit_history ON EXISTS
        (
            SELECT 1
            FROM catbench.benchmark_files
            JOIN catbench.commit_files
            ON catbench.commit_files.file_id = catbench.benchmark_files.file_id
            WHERE catbench.benchmark_files.benchmark_id = catbench.benchmarks.id
            AND catbench.commit_files.commit_id = commit_history.id
        )
        --
        -- Include only commits that have not yet been benchmarked
        -- for this specific host.
        --
        JOIN catbench.commits
        ON catbench.commits.id IN (commit_history.id, commit_history.prev_id)
        AND NOT EXISTS
        (
            SELECT 1
            FROM catbench.runs
            WHERE catbench.runs.benchmark_id = catbench.benchmarks.id
            AND catbench.runs.commit_id = catbench.commits.id
            AND catbench.runs.system_config_id = get_next_benchmark_run.system_config_id
        )
        LIMIT 1
        RETURNING
            id,
            benchmark_id,
            commit_id
    )
    SELECT
        next_run.id,
        catbench.benchmarks.name,
        catbench.benchmarks.id,
        catbench.commits.commit_hash,
        catbench.commits.id
    FROM next_run
    JOIN catbench.benchmarks ON catbench.benchmarks.id = next_run.benchmark_id
    JOIN catbench.commits ON catbench.commits.id = next_run.commit_id;
END;
