CREATE OR REPLACE FUNCTION catbench.next_benchmark
(
    system_config_id uuid
)
RETURNS TABLE
(
    run_id uuid,
    benchmark_id bigint,
    benchmark_name text,
    commit_id bigint,
    commit_hash text,
    executable_hash text
)
LANGUAGE plpgsql
AS $$
DECLARE
    RUNS_PER_BENCHMARK constant bigint = 10;
BEGIN
    SELECT
        todo.benchmark_id,
        todo.benchmark_name,
        todo.commit_id,
        todo.commit_hash
    INTO
        benchmark_id,
        benchmark_name,
        commit_id,
        commit_hash
    FROM catbench.get_benchmarks_todo(next_benchmark.system_config_id) AS todo
    --
    -- Run each benchmark 10 times
    --
    WHERE todo.count_runs < RUNS_PER_BENCHMARK
    ORDER BY todo.count_runs, todo.benchmark_id, todo.commit_id
    LIMIT 1;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    INSERT INTO catbench.runs
    (
        benchmark_id,
        system_config_id,
        commit_id
    )
    VALUES
    (
        benchmark_id,
        system_config_id,
        commit_id
    )
    RETURNING catbench.runs.id
    INTO STRICT run_id;

    -- There might not be any compilation yet,
    -- so no INTO STRICT here.
    SELECT
        catbench.compilations.executable_hash
    INTO
        executable_hash
    FROM catbench.compilations
    WHERE catbench.compilations.system_config_id = next_benchmark.system_config_id
      AND catbench.compilations.commit_id = next_benchmark.commit_id;

    RETURN NEXT;
END
$$;
