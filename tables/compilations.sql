CREATE TABLE catbench.compilations
(
    system_config_id uuid NOT NULL,
    commit_id bigint NOT NULL,
    executable_hash text,
    PRIMARY KEY (system_config_id, commit_id),
    FOREIGN KEY (system_config_id) REFERENCES catbench.system_configs (id),
    FOREIGN KEY (commit_id) REFERENCES catbench.commits (id)
);

SELECT pg_catalog.pg_extension_config_dump('catbench.compilations', '');
