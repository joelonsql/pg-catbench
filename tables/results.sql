CREATE TABLE catbench.results
(
    id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
    measure_type timeit.measure_type NOT NULL,
    x float8[] NOT NULL,
    y float8[] NOT NULL,
    r_squared float8 NOT NULL,
    slope float8 NOT NULL,
    intercept float8 NOT NULL,
    iterations bigint NOT NULL,
    benchmark_id bigint NOT NULL,
    system_config_id uuid NOT NULL,
    commit_id bigint NOT NULL,
    test_id bigint NOT NULL,
    benchmark_duration interval NOT NULL,
    result_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id),
    FOREIGN KEY (test_id) REFERENCES catbench.tests (id),
    FOREIGN KEY (benchmark_id) REFERENCES catbench.benchmarks (id),
    FOREIGN KEY (system_config_id) REFERENCES catbench.system_configs (id),
    FOREIGN KEY (commit_id) REFERENCES catbench.commits (id)
);

SELECT pg_catalog.pg_extension_config_dump('catbench.results', '');
