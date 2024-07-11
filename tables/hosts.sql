CREATE TABLE catbench.hosts
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    cpu_info jsonb NOT NULL,
    os_info jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id)
);
