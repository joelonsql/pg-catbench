CREATE OR REPLACE VIEW catbench.vresults AS
SELECT
    catbench.results.execution_time,
    catbench.results.result_at,
    catbench.benchmarks.name AS benchmark_name,
    catbench.runs.system_config_id,
    catbench.functions.name AS function_name,
    catbench.tests.x,
    catbench.tests.y,
    catbench.commits.id AS commit_id,
    catbench.commits.commit_hash,
    catbench.commits.parent_hash
FROM catbench.results
JOIN catbench.runs
  ON catbench.runs.id = catbench.results.run_id
JOIN catbench.tests
  ON catbench.tests.id = catbench.results.test_id
JOIN catbench.benchmarks
  ON catbench.benchmarks.id = catbench.runs.benchmark_id
JOIN catbench.commits
  ON catbench.commits.id = catbench.runs.commit_id
JOIN catbench.functions
  ON catbench.functions.id = catbench.tests.function_id;
