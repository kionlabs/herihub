create table if not exists herihub.blog_drafts (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  service_type text not null check (service_type in ('골동품 매입', '빈집·유품정리', '특수청소', '복합 서비스')),
  region text not null,
  topic_notes text not null,
  keywords text[] not null default '{}',
  tone text not null check (tone in ('FRIENDLY', 'EXPERT', 'CALM')),
  style_profile jsonb not null default '{}'::jsonb,
  reference_post_ids uuid[] not null default '{}',
  draft_body text not null,
  status text not null default 'DRAFT' check (status in ('DRAFT', 'READY', 'PUBLISHED')),
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint blog_drafts_title_length check (char_length(title) between 2 and 160),
  constraint blog_drafts_region_length check (char_length(region) between 2 and 80),
  constraint blog_drafts_notes_length check (char_length(topic_notes) between 10 and 3000),
  constraint blog_drafts_body_length check (char_length(draft_body) between 50 and 10000),
  constraint blog_drafts_keyword_count check (cardinality(keywords) <= 20),
  constraint blog_drafts_reference_count check (cardinality(reference_post_ids) <= 12)
);

create index if not exists blog_drafts_status_updated_idx on herihub.blog_drafts (status, updated_at desc);
alter table herihub.blog_drafts enable row level security;
revoke all privileges on table herihub.blog_drafts from anon, authenticated;
grant select, insert, update, delete on table herihub.blog_drafts to authenticated;

create policy "HeriHub admins manage blog drafts" on herihub.blog_drafts for all to authenticated
using (coalesce((select auth.jwt()) -> 'app_metadata' ->> 'herihub_role', '') = 'admin'
  and coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) = false)
with check (coalesce((select auth.jwt()) -> 'app_metadata' ->> 'herihub_role', '') = 'admin'
  and coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) = false);
