CREATE OR REPLACE FUNCTION catbench.set_executable_hash
(
    system_config_id uuid,
    commit_id bigint,
    executable_hash text
)
RETURNS void
LANGUAGE plpgsql AS
$$
DECLARE
_OK boolean;
BEGIN
    IF EXISTS
    (
        SELECT 1 FROM catbench.compilations
        WHERE catbench.compilations.system_config_id = set_executable_hash.system_config_id
          AND catbench.compilations.commit_id = set_executable_hash.commit_id
    ) THEN
        UPDATE catbench.compilations SET
            executable_hash = set_executable_hash.executable_hash
        WHERE catbench.compilations.system_config_id = set_executable_hash.system_config_id
        AND catbench.compilations.commit_id = set_executable_hash.commit_id
        RETURNING TRUE INTO STRICT _OK;
    ELSE
        INSERT INTO catbench.compilations
            (system_config_id, commit_id, executable_hash)
        VALUES
            (system_config_id, commit_id, executable_hash)
        RETURNING TRUE INTO STRICT _OK;
    END IF;
END;
$$;
