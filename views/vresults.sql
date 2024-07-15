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
        catbench.commits.parent_hash,
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
        -- 6 as z-score for Confidence Level around one in a billion
        q.avg - 6.0 * (q.stddev / SQRT(q.n)) AS ci_lower,
        q.avg + 6.0 * (q.stddev / SQRT(q.n)) AS ci_upper
    FROM q
),
non_overlapping_ci AS
(
    SELECT
        a.benchmark_name,
        a.system_config_id,
        a.function_name,
        a.x,
        a.y,
        a.commit_id AS a_commit_id,
        b.commit_id AS b_commit_id,
        a.commit_hash AS a_commit_hash,
        b.commit_hash AS b_commit_hash,
        a.avg AS a_avg,
        b.avg AS b_avg,
        a.ci_lower AS a_ci_lower,
        a.ci_upper AS a_ci_upper,
        b.ci_lower AS b_ci_lower,
        b.ci_upper AS b_ci_upper
    FROM ci AS a
    JOIN ci AS b USING (benchmark_name, system_config_id, function_name, x, y)
    WHERE a.commit_hash = b.parent_hash
    AND (a.ci_upper < b.ci_lower OR b.ci_upper < a.ci_lower)
)
SELECT
    benchmark_name,
    system_config_id,
    function_name,
    x,
    y,
    a_commit_id,
    b_commit_id,
    a_commit_hash,
    b_commit_hash,
    ARRAY
    [
        timeit.pretty_time(a_ci_lower::numeric, 2),
        timeit.pretty_time(a_avg::numeric, 2),
        timeit.pretty_time(a_ci_upper::numeric, 2)
    ] AS a_ci,
    ARRAY
    [
        timeit.pretty_time(b_ci_lower::numeric, 2),
        timeit.pretty_time(b_avg::numeric, 2),
        timeit.pretty_time(b_ci_upper::numeric, 2)
    ] AS b_ci
FROM non_overlapping_ci
ORDER BY
    benchmark_name,
    system_config_id,
    function_name,
    x,
    y,
    a_commit_id;
