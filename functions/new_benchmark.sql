CREATE OR REPLACE FUNCTION catbench.new_benchmark
(
    name text,
    generate_function text,
    hash_function text
)
RETURNS bigint
LANGUAGE SQL
BEGIN ATOMIC
    INSERT INTO catbench.benchmarks
        (name, generate_function, hash_function)
    VALUES
        (name, generate_function, hash_function)
    RETURNING id;
END;
