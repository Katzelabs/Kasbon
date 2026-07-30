-- Low stock, as something the database can filter on.
--
-- ## Why this column exists
--
-- PostgREST cannot compare two columns to each other: there is no way to ask
-- it for `stock <= min_stock`. The product list worked around that by asking
-- for a page and then dropping the non-matching rows in Dart, *after*
-- `.range()` had already chosen which rows the page contained.
--
-- That is not a filter, it is a filter applied to an arbitrary slice. Asking
-- for "stok rendah" returned a page of ten with however many of those ten
-- happened to qualify - sometimes none - while the total next to it came from
-- a count that did not apply the stock filter at all and reported every active
-- product. Page 3 of 12 could be empty, and page 4 could have rows again.
--
-- A generated column moves the comparison to where the rows are, so the page,
-- the count and the ordering all agree because they are all the same query.
--
-- ## COALESCE(min_stock, 5), not COALESCE(min_stock, 0)
--
-- `min_stock` is nullable, and `ProductModel.fromJson` reads a null as 5
-- (`json['min_stock'] as int? ?? 5`). Five is therefore the threshold the app
-- has always shown for those rows, and the column has to agree with the app
-- rather than with SQL's own instinct, or products with no explicit minimum
-- would silently change category the moment the filter moved server-side.
--
-- STORED rather than VIRTUAL because it is filtered on, not just selected:
-- only a stored generated column can be indexed.

ALTER TABLE public.products
  ADD COLUMN is_low_stock BOOLEAN
  GENERATED ALWAYS AS (stock <= COALESCE(min_stock, 5)) STORED;

COMMENT ON COLUMN public.products.is_low_stock IS
  'Generated: stock <= COALESCE(min_stock, 5). Exists so PostgREST can filter '
  'on a comparison between two columns, which it cannot express directly. '
  'Includes out-of-stock rows - the app''s "stok rendah" filter pairs this '
  'with stock > 0, and "tersedia" is this being false.';

-- Partial index, matching the queries that use it.
--
-- Every product read is scoped by `user_id` and `is_active` (RLS supplies the
-- first, the datasource the second), so the index carries the user and the
-- predicate carries the active flag. Indexing inactive rows would grow the
-- index with rows no list ever asks for.
CREATE INDEX idx_products_user_low_stock
  ON public.products (user_id, is_low_stock)
  WHERE is_active;
