CREATE TABLE catbench.benchmarks
(
    id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
    name text NOT NULL,
    generate_function text NOT NULL,
    hash_function text NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (name)
);
