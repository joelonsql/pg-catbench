CREATE OR REPLACE FUNCTION catbench.get_or_insert_file_path(file_path text)
RETURNS bigint
LANGUAGE SQL
BEGIN ATOMIC
    INSERT INTO catbench.files (file_path) VALUES (file_path)
    ON CONFLICT (file_path) DO NOTHING
    RETURNING id;
END;
