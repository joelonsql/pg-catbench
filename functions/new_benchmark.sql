CREATE FUNCTION catbench.new_benchmark(name text)
RETURNS bigint
LANGUAGE SQL
BEGIN ATOMIC
    INSERT INTO catbench.benchmarks (name)
    VALUES (name)
    RETURNING id;
END;
