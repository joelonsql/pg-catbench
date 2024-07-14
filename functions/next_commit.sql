CREATE OR REPLACE FUNCTION catbench.next_commit
(
    system_config_id uuid
)
RETURNS TABLE
(
    commit_hash text,
    commit_id bigint
)
LANGUAGE SQL
BEGIN ATOMIC
    WITH
    todo_with_first_commit AS
    (
        SELECT
            todo.benchmark_id,
            todo.commit_id,
            FIRST_VALUE(commit_id) OVER (ORDER BY commit_id) AS first_commit_id
        FROM catbench.get_benchmarks_todo(next_commit.system_config_id) AS todo
    )
    INSERT INTO catbench.runs
    (
        benchmark_id,
        system_config_id,
        commit_id
    )
    SELECT
        todo_with_first_commit.benchmark_id,
        next_commit.system_config_id,
        todo_with_first_commit.commit_id
    FROM todo_with_first_commit
    WHERE todo_with_first_commit.commit_id = todo_with_first_commit.first_commit_id;
    --
    -- start new txn so SELECT will see the possibly newly INSERT'ed row
    --
    SELECT
        catbench.commits.commit_hash,
        catbench.commits.id
    FROM catbench.runs
    JOIN catbench.commits
    ON catbench.commits.id = catbench.runs.commit_id
    WHERE catbench.runs.system_config_id = next_commit.system_config_id
      AND catbench.runs.started_at IS NULL
    ORDER BY catbench.commits.id
    LIMIT 1;
END;
