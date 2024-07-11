CREATE TABLE catbench.functions
(
    id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
    name text NOT NULL,
    benchmark_id bigint NOT NULL,
    x_label text NOT NULL,
    y_label text,
    PRIMARY KEY (id),
    UNIQUE (name),
    FOREIGN KEY (benchmark_id) REFERENCES catbench.benchmarks (id)
);
