CREATE OR REPLACE FUNCTION catbench.insert_result
(
    measure_type timeit.measure_type,
    x float8[],
    y float8[],
    r_squared float8,
    slope float8,
    intercept float8,
    iterations bigint,
    benchmark_id bigint,
    system_config_id uuid,
    commit_id bigint,
    test_id bigint,
    benchmark_duration interval
)
RETURNS uuid
LANGUAGE SQL
BEGIN ATOMIC
    INSERT INTO catbench.results
        (measure_type, x, y, r_squared, slope, intercept, iterations, benchmark_id, system_config_id, commit_id, test_id, benchmark_duration)
    VALUES
        (measure_type, x, y, r_squared, slope, intercept, iterations, benchmark_id, system_config_id, commit_id, test_id, benchmark_duration)
    RETURNING id;
END;
