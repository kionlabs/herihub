create table if not exists herihub.blog_sources (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  blog_id text not null unique,
  blog_url text not null,
  rss_url text not null unique,
  enabled boolean not null default true,
  last_synced_at timestamp with time zone,
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint blog_sources_name_length check (char_length(name) between 2 and 80),
  constraint blog_sources_id_length check (char_length(blog_id) between 3 and 80),
  constraint blog_sources_url_length check (char_length(blog_url) <= 500 and char_length(rss_url) <= 500)
);

create table if not exists herihub.blog_posts (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references herihub.blog_sources(id) on delete cascade,
  external_post_id text not null,
  title text not null,
  category text,
  excerpt text not null,
  original_url text not null,
  thumbnail_url text,
  published_at timestamp with time zone,
  workflow_status text not null default 'NEW' check (workflow_status in ('NEW', 'IMPORTED', 'IGNORED')),
  review_id uuid references herihub.reviews(id) on delete set null,
  fetched_at timestamp with time zone not null default timezone('utc', now()),
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint blog_posts_source_external_unique unique (source_id, external_post_id),
  constraint blog_posts_title_length check (char_length(title) between 1 and 200),
  constraint blog_posts_excerpt_length check (char_length(excerpt) between 1 and 1200),
  constraint blog_posts_url_length check (char_length(original_url) <= 500),
  constraint blog_posts_thumbnail_length check (thumbnail_url is null or char_length(thumbnail_url) <= 1000)
);

create index if not exists blog_posts_workflow_idx on herihub.blog_posts (workflow_status, published_at desc nulls last);
create index if not exists blog_posts_source_idx on herihub.blog_posts (source_id, published_at desc nulls last);

alter table herihub.blog_sources enable row level security;
alter table herihub.blog_posts enable row level security;
revoke all privileges on table herihub.blog_sources from anon, authenticated;
revoke all privileges on table herihub.blog_posts from anon, authenticated;
grant select, insert, update, delete on table herihub.blog_sources to authenticated;
grant select, insert, update, delete on table herihub.blog_posts to authenticated;

create policy "HeriHub admins manage blog sources" on herihub.blog_sources for all to authenticated
using (coalesce((select auth.jwt()) -> 'app_metadata' ->> 'herihub_role', '') = 'admin' and coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) = false)
with check (coalesce((select auth.jwt()) -> 'app_metadata' ->> 'herihub_role', '') = 'admin' and coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) = false);

create policy "HeriHub admins manage blog posts" on herihub.blog_posts for all to authenticated
using (coalesce((select auth.jwt()) -> 'app_metadata' ->> 'herihub_role', '') = 'admin' and coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) = false)
with check (coalesce((select auth.jwt()) -> 'app_metadata' ->> 'herihub_role', '') = 'admin' and coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) = false);

insert into herihub.blog_sources (name, blog_id, blog_url, rss_url)
values
  ('담성갤러리', 'gustjr4456', 'https://m.blog.naver.com/gustjr4456', 'https://rss.blog.naver.com/gustjr4456.xml'),
  ('다와 유품정리', 'djfzmsgkssjrnfl1', 'https://m.blog.naver.com/djfzmsgkssjrnfl1', 'https://rss.blog.naver.com/djfzmsgkssjrnfl1.xml')
on conflict (blog_id) do update set name = excluded.name, blog_url = excluded.blog_url, rss_url = excluded.rss_url, enabled = true, updated_at = timezone('utc', now());
