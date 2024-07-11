CREATE OR REPLACE FUNCTION catbench.new_file_mapping
(
    name text,
    file_path text
)
RETURNS bigint
LANGUAGE SQL
BEGIN ATOMIC
    INSERT INTO catbench.file_mappings
        (benchmark_id, file_path)
    VALUES
        (
            catbench.get_benchmark_id(name),
            file_path
        )
    RETURNING id;
END;
