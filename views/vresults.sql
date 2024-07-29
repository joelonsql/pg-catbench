CREATE OR REPLACE VIEW catbench.vresults AS
SELECT
    catbench.results.measure_type,
    catbench.results.slope,
    catbench.results.result_at,
    catbench.benchmarks.name AS benchmark_name,
    catbench.results.system_config_id,
    catbench.functions.name AS function_name,
    catbench.tests.x,
    catbench.tests.y,
    catbench.commits.id AS commit_id,
    catbench.commits.commit_hash,
    catbench.commits.parent_hash,
    catbench.results.x AS result_x,
    catbench.results.y AS result_y,
    catbench.results.r_squared,
    catbench.results.intercept
FROM catbench.results
JOIN catbench.tests
  ON catbench.tests.id = catbench.results.test_id
JOIN catbench.benchmarks
  ON catbench.benchmarks.id = catbench.results.benchmark_id
JOIN catbench.commits
  ON catbench.commits.id = catbench.results.commit_id
JOIN catbench.functions
  ON catbench.functions.id = catbench.tests.function_id;
