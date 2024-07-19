CREATE TABLE catbench.benchmark_files
(
    id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
    benchmark_id bigint NOT NULL,
    file_id bigint NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (benchmark_id) REFERENCES catbench.benchmarks (id),
    FOREIGN KEY (file_id) REFERENCES catbench.files (id)
);

SELECT pg_catalog.pg_extension_config_dump('catbench.benchmark_files', '');
