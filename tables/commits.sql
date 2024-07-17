CREATE TABLE catbench.commits
(
    id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
    commit_hash text NOT NULL,
    parent_hash text,
    summary TEXT,
    commit_time TIMESTAMPTZ,
    PRIMARY KEY (id),
    FOREIGN KEY (parent_hash) REFERENCES catbench.commits (commit_hash),
    UNIQUE (commit_hash),
    CHECK (commit_hash ~ '^[0-9a-f]{40}$')
);
