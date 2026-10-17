create table if not exists herihub.reviews (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,
  service_type text not null check (service_type in ('골동품 매입', '빈집·유품정리', '특수청소', '복합 서비스')),
  region text not null,
  review_body text not null,
  author_label text not null default '고객님',
  rating smallint not null default 5 check (rating between 1 and 5),
  image_url text,
  source_type text not null default 'DIRECT' check (source_type in ('DIRECT', 'BLOG_COMMENT', 'WORK_CASE')),
  source_url text,
  is_published boolean not null default false,
  published_at timestamp with time zone,
  sort_order integer not null default 0,
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint reviews_title_length check (char_length(title) between 2 and 120),
  constraint reviews_category_length check (char_length(category) between 2 and 80),
  constraint reviews_region_length check (char_length(region) between 2 and 80),
  constraint reviews_body_length check (char_length(review_body) between 10 and 1200),
  constraint reviews_author_length check (char_length(author_label) between 2 and 40),
  constraint reviews_image_url_length check (image_url is null or char_length(image_url) <= 500),
  constraint reviews_source_url_length check (source_url is null or char_length(source_url) <= 500),
  constraint reviews_published_at_required check (not is_published or published_at is not null)
);

create index if not exists reviews_public_feed_idx
  on herihub.reviews (is_published, sort_order desc, published_at desc);

alter table herihub.reviews enable row level security;
revoke all privileges on table herihub.reviews from anon, authenticated;
grant usage on schema herihub to anon, authenticated;
grant select on table herihub.reviews to anon;
grant select, insert, update, delete on table herihub.reviews to authenticated;
