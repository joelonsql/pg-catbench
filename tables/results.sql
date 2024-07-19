CREATE TABLE catbench.results
(
    id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
    execution_time float8 NOT NULL,
    run_id uuid NOT NULL,
    test_id bigint NOT NULL,
    result_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id),
    FOREIGN KEY (run_id) REFERENCES catbench.runs (id),
    FOREIGN KEY (test_id) REFERENCES catbench.tests (id)
);

SELECT pg_catalog.pg_extension_config_dump('catbench.results', '');
