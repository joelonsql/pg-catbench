SELECT catbench.new_benchmark('numeric', 'generate_numeric', 'hash_numeric');
SELECT catbench.new_benchmark_file('numeric', 'src/backend/utils/adt/numeric.c');
SELECT catbench.new_function('numeric', 'numeric_add', 'var1ndigits', 'var2ndigits');
SELECT catbench.new_function('numeric', 'numeric_mul', 'var1ndigits', 'var2ndigits');
SELECT catbench.new_function('numeric', 'numeric_div', 'var1ndigits', 'var2ndigits');
SELECT catbench.new_function('numeric', 'numeric_sqrt', 'ndigits');

CREATE OR REPLACE FUNCTION catbench.generate_numeric(ndigits numeric)
RETURNS numeric
LANGUAGE SQL
BEGIN ATOMIC
    SELECT random
    (
        round(10000::numeric^(ndigits-1)),
        round(10000::numeric^ndigits-1)
    );
END;

WITH RECURSIVE
series AS
(
    SELECT 16384::numeric AS ndigits
    UNION ALL
    SELECT CASE
             WHEN round(ndigits * 0.5) >= 4 THEN round(ndigits * 0.5)
             ELSE ndigits - 1
           END
    FROM series
    WHERE ndigits > 1
),
insert_binary AS
(
    INSERT INTO catbench.tests
        (function_id, x, y)
    SELECT
        catbench.get_function_id('numeric', function_name),
        var1.ndigits,
        var2.ndigits
    FROM unnest(ARRAY['numeric_add', 'numeric_mul', 'numeric_div']) AS function_name
    CROSS JOIN series AS var1
    CROSS JOIN series AS var2
    CROSS JOIN generate_series(1,3)
    WHERE var1.ndigits <= var2.ndigits
),
insert_balanced_tests AS
(
    INSERT INTO catbench.tests
        (function_id, x, y)
    VALUES
        (catbench.get_function_id('numeric', 'numeric_mul'), 5, 5),
        (catbench.get_function_id('numeric', 'numeric_mul'), 6, 6),
        (catbench.get_function_id('numeric', 'numeric_mul'), 7, 7)
)
INSERT INTO catbench.tests
    (function_id, x)
SELECT
    catbench.get_function_id('numeric', 'numeric_sqrt'),
    series.ndigits
FROM series
CROSS JOIN generate_series(1,3);
