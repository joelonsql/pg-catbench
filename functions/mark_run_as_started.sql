CREATE OR REPLACE FUNCTION catbench.mark_run_as_started(run_id uuid)
RETURNS void
LANGUAGE plpgsql AS
$$
DECLARE
_OK boolean;
BEGIN
    UPDATE catbench.runs
    SET started_at = now()
    WHERE catbench.runs.id = mark_run_as_started.run_id
    AND started_at IS NULL
    RETURNING TRUE INTO STRICT _OK;
END;
$$;
