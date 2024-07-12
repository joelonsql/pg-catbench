CREATE OR REPLACE PROCEDURE catbench.merge_new_commits()
LANGUAGE plpgsql AS
$$
BEGIN
--
-- delete already imported commits from temp table
--
DELETE FROM pg_temp.commit_files
WHERE EXISTS
(
    SELECT 1 FROM catbench.commits
    WHERE catbench.commits.commit_hash = pg_temp.commit_files.commit_hash
);
--
-- insert new commits in commit order
--
WITH
sort_new_commits AS
(
    SELECT commit_hash, MAX(id) AS id
    FROM pg_temp.commit_files
    GROUP BY commit_hash
)
INSERT INTO catbench.commits (commit_hash)
SELECT commit_hash FROM sort_new_commits
ORDER BY id DESC;
--
-- insert new files
--
INSERT INTO catbench.files (file_path)
SELECT DISTINCT file_path
FROM pg_temp.commit_files
WHERE NOT EXISTS
(
    SELECT 1 FROM catbench.files
    WHERE catbench.files.file_path = pg_temp.commit_files.file_path
);
--
-- insert mapped ids for file changes for all new commits
--
INSERT INTO catbench.commit_files (commit_id, file_id)
SELECT
    catbench.commits.id,
    catbench.files.id
FROM pg_temp.commit_files
JOIN catbench.commits ON catbench.commits.commit_hash =  pg_temp.commit_files.commit_hash
JOIN catbench.files ON catbench.files.file_path = pg_temp.commit_files.file_path;
END
$$;
