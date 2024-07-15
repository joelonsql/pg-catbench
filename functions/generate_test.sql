CREATE OR REPLACE FUNCTION catbench.generate_test(test_id bigint)
RETURNS TABLE
(
    function_name text,
    input_values text[]
)
LANGUAGE plpgsql AS
$$
DECLARE
    _generate_function text;
    _hash_function text;
    _x numeric;
    _y numeric;
    _xval text;
    _yval text;
    _cur_hash_value integer;
    _new_hash_value integer;
    _seed_value float8;
BEGIN
    SELECT
        catbench.benchmarks.generate_function,
        catbench.benchmarks.hash_function,
        catbench.functions.name,
        catbench.tests.x,
        catbench.tests.y,
        catbench.tests.hash_value,
        catbench.tests.seed_value
    INTO STRICT
        _generate_function,
        _hash_function,
        function_name,
        _x,
        _y,
        _cur_hash_value,
        _seed_value
    FROM catbench.tests
    JOIN catbench.functions
      ON catbench.functions.id = catbench.tests.function_id
    JOIN catbench.benchmarks
      ON catbench.benchmarks.id = catbench.functions.benchmark_id
    WHERE catbench.tests.id = generate_test.test_id;

    PERFORM setseed(_seed_value);

    EXECUTE format('SELECT catbench.%1$I(%2$L::numeric)::text', _generate_function, _x)
    INTO STRICT _xval;

    IF _y IS NOT NULL THEN
        EXECUTE format('SELECT catbench.%1$I(%2$L::numeric)::text', _generate_function, _y)
        INTO STRICT _yval;
        input_values := ARRAY[_xval, _yval];
        EXECUTE format('SELECT %1$I(%2$I(%3$L,%4$L))', _hash_function, function_name, _xval, _yval)
        INTO STRICT _new_hash_value;
    ELSE
        input_values := ARRAY[_xval];
        EXECUTE format('SELECT %1$I(%2$I(%3$L))', _hash_function, function_name, _xval)
        INTO STRICT _new_hash_value;
    END IF;

    IF _cur_hash_value IS NULL AND _new_hash_value IS NOT NULL
    THEN
        UPDATE catbench.tests
        SET hash_value = _new_hash_value
        WHERE catbench.tests.id = generate_test.test_id
        RETURNING hash_value INTO STRICT _cur_hash_value;
    END IF;

    IF _cur_hash_value IS DISTINCT FROM _new_hash_value THEN
        RAISE EXCEPTION 'Bug! Test id % produced a different result!', test_id;
    END IF;

    RETURN NEXT;
END
$$;
