drop policy if exists "Public can read published reviews" on herihub.reviews;
drop policy if exists "HeriHub admins can read all reviews" on herihub.reviews;
drop policy if exists "HeriHub admins can insert reviews" on herihub.reviews;
drop policy if exists "HeriHub admins can update reviews" on herihub.reviews;
drop policy if exists "HeriHub admins can delete reviews" on herihub.reviews;

create policy "Public can read published reviews"
on herihub.reviews for select to anon
using (is_published = true);

create policy "HeriHub admins can read all reviews"
on herihub.reviews for select to authenticated
using (coalesce((select auth.jwt()) -> 'app_metadata' ->> 'herihub_role', '') = 'admin'
  and coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) = false);

create policy "HeriHub admins can insert reviews"
on herihub.reviews for insert to authenticated
with check (coalesce((select auth.jwt()) -> 'app_metadata' ->> 'herihub_role', '') = 'admin'
  and coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) = false);

create policy "HeriHub admins can update reviews"
on herihub.reviews for update to authenticated
using (coalesce((select auth.jwt()) -> 'app_metadata' ->> 'herihub_role', '') = 'admin'
  and coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) = false)
with check (coalesce((select auth.jwt()) -> 'app_metadata' ->> 'herihub_role', '') = 'admin'
  and coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) = false);

create policy "HeriHub admins can delete reviews"
on herihub.reviews for delete to authenticated
using (coalesce((select auth.jwt()) -> 'app_metadata' ->> 'herihub_role', '') = 'admin'
  and coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) = false);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'herihub' and tablename = 'reviews'
  ) then
    execute 'alter publication supabase_realtime add table herihub.reviews';
  end if;
end
$$;
