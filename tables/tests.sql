CREATE TABLE catbench.tests
(
    id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
    function_id bigint NOT NULL,
    x numeric NOT NULL,
    y numeric,
    hash_value integer,
    seed_value float8 NOT NULL DEFAULT (random() * 2 - 1)::float8,
    PRIMARY KEY (id),
    FOREIGN KEY (function_id) REFERENCES catbench.functions (id)
);
