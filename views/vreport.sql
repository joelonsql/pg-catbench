CREATE OR REPLACE VIEW catbench.vreport AS
WITH
q AS
(
    SELECT
        catbench.benchmarks.name AS benchmark_name,
        catbench.runs.system_config_id,
        catbench.functions.name AS function_name,
        catbench.tests.x,
        catbench.tests.y,
        catbench.commits.id AS commit_id,
        catbench.commits.commit_hash,
        catbench.commits.parent_hash,
        catbench.commits.summary,
        AVG(catbench.results.execution_time) AS avg,
        STDDEV(catbench.results.execution_time) AS stddev,
        COUNT(*) AS n
    FROM catbench.results
    JOIN catbench.runs
      ON catbench.runs.id = catbench.results.run_id
    JOIN catbench.benchmarks
      ON catbench.benchmarks.id = catbench.runs.benchmark_id
    JOIN catbench.commits
      ON catbench.commits.id = catbench.runs.commit_id
    JOIN catbench.tests
      ON catbench.tests.id = catbench.results.test_id
    JOIN catbench.functions
      ON catbench.functions.id = catbench.tests.function_id
    GROUP BY
        catbench.benchmarks.name,
        catbench.runs.system_config_id,
        catbench.functions.name,
        catbench.tests.x,
        catbench.tests.y,
        catbench.commits.id,
        catbench.commits.commit_hash
),
q2 AS
(
    SELECT
        b.benchmark_name,
        b.system_config_id,
        b.function_name,
        b.x,
        b.y,
        b.commit_id,
        b.commit_hash,
        a.avg AS a_avg,
        b.avg AS b_avg,
        a.stddev AS a_stddev,
        b.stddev AS b_stddev,
        a.n AS a_n,
        b.n AS b_n,
        b.summary,
        SQRT(((a.n - 1) * POWER(a.stddev, 2) + (b.n - 1) * POWER(b.stddev, 2)) / (a.n + b.n - 2)) AS pooled_stddev
    FROM q AS a
    JOIN q AS b
      ON b.benchmark_name   = a.benchmark_name
     AND b.system_config_id = a.system_config_id
     AND b.function_name    = a.function_name
     AND b.x IS NOT DISTINCT FROM a.x
     AND b.y IS NOT DISTINCT FROM a.y
    WHERE a.commit_hash = b.parent_hash
)
SELECT
    commit_id,
    commit_hash,
    summary,
    benchmark_name,
    system_config_id,
    function_name,
    x,
    y,
    timeit.pretty_time(a_avg::numeric,2) AS a_avg,
    timeit.pretty_time(b_avg::numeric,2) AS b_avg,
    timeit.pretty_time(pooled_stddev::numeric,2) AS pooled_stddev,
    timeit.pretty_time((b_avg - a_avg)::numeric,2) AS abs_diff,
    ROUND((b_avg / a_avg - 1.0)::numeric * 100) AS rel_diff,
    ROUND(ABS(b_avg - a_avg) / pooled_stddev) AS sigmas
FROM q2
ORDER BY
    commit_id,
    benchmark_name,
    system_config_id,
    function_name,
    x,
    y;
