CREATE OR REPLACE FUNCTION catbench.insert_result
(
    test_id bigint,
    run_id uuid,
    execution_time float8
)
RETURNS uuid
LANGUAGE SQL
BEGIN ATOMIC
    INSERT INTO catbench.results
        (test_id, run_id, execution_time)
    VALUES
        (test_id, run_id, execution_time)
    RETURNING id;
END;
