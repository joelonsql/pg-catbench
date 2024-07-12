CREATE OR REPLACE FUNCTION catbench.get_commit_id(commit_hash text)
RETURNS bigint
LANGUAGE SQL
STABLE
BEGIN ATOMIC
    SELECT catbench.commits.id
    FROM catbench.commits
    WHERE catbench.commits.commit_hash = get_commit_id.commit_hash;
END;
