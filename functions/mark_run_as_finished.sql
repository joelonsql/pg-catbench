CREATE OR REPLACE FUNCTION catbench.mark_run_as_finished(run_id uuid)
RETURNS void
LANGUAGE plpgsql AS
$$
DECLARE
_OK boolean;
BEGIN
    UPDATE catbench.runs
    SET finished_at = now()
    WHERE catbench.runs.id = mark_run_as_finished.run_id
    AND finished_at IS NULL
    RETURNING TRUE INTO STRICT _OK;
END;
$$;
