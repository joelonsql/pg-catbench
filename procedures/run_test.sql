CREATE OR REPLACE PROCEDURE catbench.run_test
(
    test_id bigint,
    run_id uuid
)
LANGUAGE plpgsql AS
$$
DECLARE
    _generate_function text;
    _hash_function text;
    _function_name text;
    _input_values text[];
    _execution_time numeric;
    _x numeric;
    _y numeric;
    _xval text;
    _yval text;
    _cur_hash_value integer;
    _new_hash_value integer;
BEGIN
    SELECT
        catbench.benchmarks.generate_function,
        catbench.benchmarks.hash_function,
        catbench.functions.name,
        catbench.tests.x,
        catbench.tests.y,
        catbench.tests.hash_value
    INTO STRICT
        _generate_function,
        _hash_function,
        _function_name,
        _x,
        _y,
        _cur_hash_value
    FROM catbench.tests
    JOIN catbench.functions
      ON catbench.functions.id = catbench.tests.function_id
    JOIN catbench.benchmarks
      ON catbench.benchmarks.id = catbench.functions.benchmark_id
    WHERE catbench.tests.id = run_test.test_id;

    EXECUTE format('SELECT catbench.%1$I(%2$L::numeric)::text', _generate_function, _x)
    INTO STRICT _xval;

    IF _y IS NOT NULL THEN
        EXECUTE format('SELECT catbench.%1$I(%2$L::numeric)::text', _generate_function, _y)
        INTO STRICT _yval;
        _input_values := ARRAY[_xval, _yval];
        EXECUTE format('SELECT %1$I(%2$I(%3$L,%4$L))', _hash_function, _function_name, _xval, _yval)
        INTO STRICT _new_hash_value;
    ELSE
        _input_values := ARRAY[_xval];
        EXECUTE format('SELECT %1$I(%2$I(%3$L))', _hash_function, _function_name, _xval)
        INTO STRICT _new_hash_value;
    END IF;

    IF _cur_hash_value IS NULL AND _new_hash_value IS NOT NULL
    THEN
        UPDATE catbench.tests
        SET hash_value = _new_hash_value
        WHERE catbench.tests.id = run_test.test_id
        RETURNING hash_value INTO STRICT _cur_hash_value;
    END IF;

    IF _cur_hash_value IS DISTINCT FROM _new_hash_value THEN
        RAISE EXCEPTION 'Bug! Test id % produced a different result!', test_id;
    END IF;

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
