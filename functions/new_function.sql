CREATE OR REPLACE FUNCTION catbench.new_function
(
    benchmark_name text,
    function_name text,
    x_label text,
    y_label text DEFAULT NULL
)
RETURNS bigint
LANGUAGE SQL
BEGIN ATOMIC
    INSERT INTO catbench.functions
        (benchmark_id, name, x_label, y_label)
    VALUES
        (
            catbench.get_benchmark_id(benchmark_name),
            function_name,
            x_label,
            y_label
        )
    RETURNING id;
END;
