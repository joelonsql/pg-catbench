CREATE TABLE catbench.tests
(
    id bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
    function_id bigint NOT NULL,
    x numeric NOT NULL,
    y numeric,
    hash_value integer,
    PRIMARY KEY (id),
    FOREIGN KEY (function_id) REFERENCES catbench.functions (id)
);
