-- HeriHub public estimate intake and admin-only management.
-- Admin users must have app_metadata.herihub_role = 'admin', assigned server-side.

alter table herihub.estimates enable row level security;

drop policy if exists "Allow anonymous to insert estimates" on herihub.estimates;
drop policy if exists "Allow authenticated admin full access" on herihub.estimates;
drop policy if exists "Public can submit valid estimates" on herihub.estimates;
drop policy if exists "HeriHub admins can read estimates" on herihub.estimates;
drop policy if exists "HeriHub admins can update estimates" on herihub.estimates;
drop policy if exists "HeriHub admins can delete estimates" on herihub.estimates;

revoke all privileges on table herihub.estimates from anon, authenticated;
grant insert (phone, service_type, region_and_memo)
  on table herihub.estimates to anon, authenticated;
grant select, delete
  on table herihub.estimates to authenticated;
grant update (status)
  on table herihub.estimates to authenticated;

alter table herihub.estimates
  alter column status set not null,
  alter column region_and_memo set not null;

alter table herihub.estimates
  drop constraint if exists estimates_status_allowed,
  drop constraint if exists estimates_phone_format,
  drop constraint if exists estimates_service_type_allowed,
  drop constraint if exists estimates_memo_length;

alter table herihub.estimates
  add constraint estimates_status_allowed
    check (status in ('PENDING', 'CONTACTED', 'COMPLETED')),
  add constraint estimates_phone_format
    check (phone ~ '^01[0-9]-[0-9]{3,4}-[0-9]{4}$'),
  add constraint estimates_service_type_allowed
    check (service_type in ('빈집/유품정리', '골동품/소장품 매입', '둘 다')),
  add constraint estimates_memo_length
    check (char_length(region_and_memo) between 5 and 500);

create policy "Public can submit valid estimates"
on herihub.estimates
for insert
to anon, authenticated
with check (
  status = 'PENDING'
  and phone ~ '^01[0-9]-[0-9]{3,4}-[0-9]{4}$'
  and service_type in ('빈집/유품정리', '골동품/소장품 매입', '둘 다')
  and char_length(region_and_memo) between 5 and 500
);

create policy "HeriHub admins can read estimates"
on herihub.estimates
for select
to authenticated
using (
  coalesce((select auth.jwt()) -> 'app_metadata' ->> 'herihub_role', '') = 'admin'
  and coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) = false
);

create policy "HeriHub admins can update estimates"
on herihub.estimates
for update
to authenticated
using (
  coalesce((select auth.jwt()) -> 'app_metadata' ->> 'herihub_role', '') = 'admin'
  and coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) = false
)
with check (
  coalesce((select auth.jwt()) -> 'app_metadata' ->> 'herihub_role', '') = 'admin'
  and coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) = false
);

create policy "HeriHub admins can delete estimates"
on herihub.estimates
for delete
to authenticated
using (
  coalesce((select auth.jwt()) -> 'app_metadata' ->> 'herihub_role', '') = 'admin'
  and coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) = false
);

alter table herihub.estimates_logs enable row level security;
revoke all privileges on table herihub.estimates_logs from anon, authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'herihub'
      and tablename = 'estimates'
  ) then
    execute 'alter publication supabase_realtime add table herihub.estimates';
  end if;
end
$$;
