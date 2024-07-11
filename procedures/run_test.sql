CREATE OR REPLACE PROCEDURE catbench.run_test
(
    test_id bigint,
    run_id uuid
)
LANGUAGE plpgsql AS
$$
DECLARE
    _function_name text;
    _input_values text[];
    _execution_time numeric;
BEGIN
    SELECT
        catbench.functions.name,
        catbench.tests.input_values
    INTO STRICT
        _function_name,
        _input_values
    FROM catbench.tests
    JOIN catbench.functions
        ON catbench.functions.id = catbench.tests.function_id
    WHERE catbench.tests.id = run_test.test_id;
    COMMIT;
    _execution_time := timeit.s
    (
        function_name := _function_name,
        input_values := _input_values,
        significant_figures := 2,
        timeout := '10 seconds'::interval,
        attempts := 3,
        min_time := '100 ms'::interval
    );
    INSERT INTO catbench.results
        (test_id, run_id, execution_time)
    VALUES
        (test_id, run_id, _execution_time);
END
$$;
