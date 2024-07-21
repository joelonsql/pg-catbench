CREATE OR REPLACE VIEW catbench.vcommits AS
WITH
most_significant_changes_per_commit AS
(
  SELECT
      *,
      ROW_NUMBER() OVER (PARTITION BY commit_id ORDER BY sigmas DESC)
  FROM catbench.vreport
)
SELECT * FROM most_significant_changes_per_commit
WHERE ROW_NUMBER = 1
ORDER BY commit_id;
