CREATE OR REPLACE VIEW catbench.vresults AS
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
ci AS
(
    SELECT
        q.*,
        q.avg - 1.96 * (q.stddev / SQRT(q.n)) AS ci_lower,
        q.avg + 1.96 * (q.stddev / SQRT(q.n)) AS ci_upper
    FROM q
)
SELECT
    ci.benchmark_name,
    ci.system_config_id,
    ci.function_name,
    ci.x,
    ci.y,
    ci.commit_id,
    ci.commit_hash,
    timeit.pretty_time(ci.avg::numeric, 2) AS avg,
    timeit.pretty_time(ci.stddev::numeric, 2) AS stddev,
    ci.n,
    timeit.pretty_time(ci.ci_lower::numeric, 2) AS ci_lower,
    timeit.pretty_time(ci.ci_upper::numeric, 2) AS ci_upper
FROM ci
ORDER BY
    ci.benchmark_name,
    ci.system_config_id,
    ci.function_name,
    ci.x,
    ci.y,
    ci.commit_id;
