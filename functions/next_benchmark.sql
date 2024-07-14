CREATE OR REPLACE FUNCTION catbench.next_benchmark
(
    system_config_id uuid,
    commit_id bigint
)
RETURNS TABLE
(
    run_id uuid,
    benchmark_name text,
    benchmark_id bigint
)
LANGUAGE SQL
BEGIN ATOMIC
    WITH
    next_run AS
    (
        SELECT
            catbench.runs.id,
            catbench.runs.benchmark_id
        FROM catbench.runs
        WHERE catbench.runs.system_config_id = next_benchmark.system_config_id
          AND catbench.runs.commit_id = next_benchmark.commit_id
          AND catbench.runs.started_at IS NULL
        FOR UPDATE SKIP LOCKED
        LIMIT 1
    ),
    mark_as_started AS
    (
        UPDATE catbench.runs SET started_at = now()
        FROM next_run
        WHERE catbench.runs.id = next_run.id
          AND catbench.runs.started_at IS NULL
        RETURNING catbench.runs.id
    )
    SELECT
        catbench.runs.id,
        catbench.benchmarks.name,
        catbench.benchmarks.id
    FROM mark_as_started
    JOIN catbench.runs
      ON catbench.runs.id = mark_as_started.id
    JOIN catbench.benchmarks
      ON catbench.benchmarks.id = catbench.runs.benchmark_id;
END;
