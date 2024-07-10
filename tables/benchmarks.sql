CREATE TABLE catbench.benchmarks
(
    id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
    name text NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (name)
);
