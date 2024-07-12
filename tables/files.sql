CREATE TABLE catbench.files
(
    id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
    file_path text NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (file_path)
);
