CREATE TABLE catbench.runs
(
    id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
    benchmark_id bigint NOT NULL,
    system_config_id uuid NOT NULL,
    commit_id bigint NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    started_at timestamptz,
    finished_at timestamptz,
    PRIMARY KEY (id),
    FOREIGN KEY (benchmark_id) REFERENCES catbench.benchmarks (id),
    FOREIGN KEY (system_config_id) REFERENCES catbench.system_configs (id),
    FOREIGN KEY (commit_id) REFERENCES catbench.commits (id)
);

SELECT pg_catalog.pg_extension_config_dump('catbench.runs', '');
