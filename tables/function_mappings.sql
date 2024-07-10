CREATE TABLE catbench.function_mappings
(
    id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
    benchmark_id bigint NOT NULL,
    function_name text NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (benchmark_id) REFERENCES catbench.benchmarks (id)
);
