CREATE TABLE catbench.file_mappings
(
    id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
    benchmark_id bigint NOT NULL,
    file_path text NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (benchmark_id) REFERENCES catbench.benchmarks (id)
);
