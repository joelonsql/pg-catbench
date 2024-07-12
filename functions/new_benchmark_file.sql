CREATE OR REPLACE FUNCTION catbench.new_benchmark_file
(
    benchmark_name text,
    file_path text
)
RETURNS bigint
LANGUAGE SQL
BEGIN ATOMIC

    INSERT INTO catbench.benchmark_files
        (benchmark_id, file_id)
    VALUES
        (
            catbench.get_benchmark_id(benchmark_name),
            catbench.get_or_insert_file_path(file_path)
        )
    RETURNING id;
END;
