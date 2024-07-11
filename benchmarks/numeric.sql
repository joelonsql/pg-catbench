SELECT catbench.new_benchmark('numeric', 'generate_numeric', 'hash_numeric');
SELECT catbench.new_file_mapping('numeric', 'src/backend/utils/adt/numeric.c');
SELECT catbench.new_function('numeric', 'numeric_mul', 'var1ndigits', 'var2ndigits');

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

WITH RECURSIVE series AS
(
    SELECT 16384::numeric AS ndigits
    UNION ALL
    SELECT CASE
             WHEN round(ndigits * 0.5) > 4 THEN round(ndigits * 0.5)
             ELSE ndigits - 1
           END
    FROM series
    WHERE ndigits > 1
)
INSERT INTO catbench.tests
    (function_id, x, y)
SELECT
    catbench.get_function_id('numeric', 'numeric_mul'),
    var1.ndigits,
    var2.ndigits
FROM series AS var1
CROSS JOIN series AS var2
WHERE var1.ndigits <= var2.ndigits;
