CREATE TABLE catbench.runs
(
    id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
    benchmark_id bigint NOT NULL,
    host_id uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz,
    PRIMARY KEY (id),
    FOREIGN KEY (benchmark_id) REFERENCES catbench.benchmarks (id),
    FOREIGN KEY (host_id) REFERENCES catbench.hosts (id)
);
