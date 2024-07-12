CREATE TABLE catbench.commit_files
(
    commit_id bigint NOT NULL,
    file_id bigint NOT NULL,
    PRIMARY KEY (commit_id, file_id)
);

CREATE INDEX ON catbench.commit_files (file_id);
