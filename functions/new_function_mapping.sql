CREATE FUNCTION catbench.new_function_mapping
(
    name text,
    function_name text
)
RETURNS bigint
LANGUAGE SQL
BEGIN ATOMIC
    INSERT INTO catbench.function_mappings
        (benchmark_id, function_name)
    VALUES
        (
            catbench.get_benchmark(name),
            function_name
        )
    RETURNING id;
END;
