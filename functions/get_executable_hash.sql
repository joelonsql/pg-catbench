CREATE OR REPLACE FUNCTION catbench.get_executable_hash
(
    system_config_id uuid,
    commit_id bigint
)
RETURNS text
LANGUAGE SQL
BEGIN ATOMIC
    SELECT
        catbench.compilations.executable_hash
    FROM catbench.compilations
    WHERE catbench.compilations.system_config_id = get_executable_hash.system_config_id
      AND catbench.compilations.commit_id        = get_executable_hash.commit_id;
END;
