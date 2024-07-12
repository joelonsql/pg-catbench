CREATE TABLE catbench.commits
(
    id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
    commit_hash text NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (commit_hash),
    CHECK (commit_hash ~ '^[0-9a-f]{40}$')
);
