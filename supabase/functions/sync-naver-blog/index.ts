import { createClient } from "npm:@supabase/supabase-js@2.95.0";
import { XMLParser } from "npm:fast-xml-parser@5.2.5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
});

const asText = (value: unknown) => {
  if (typeof value === "string") return value;
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    return String(record["#text"] ?? record.__cdata ?? "");
  }
  return String(value ?? "");
};

const cleanText = (html: string) => html
  .replace(/<img\b[^>]*>/gi, " ")
  .replace(/<br\s*\/?\s*>/gi, " ")
  .replace(/<[^>]+>/g, " ")
  .replace(/&nbsp;/gi, " ")
  .replace(/&amp;/gi, "&")
  .replace(/&lt;/gi, "<")
  .replace(/&gt;/gi, ">")
  .replace(/&quot;/gi, '"')
  .replace(/&#39;/gi, "'")
  .replace(/\s+/g, " ")
  .trim();

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "POST 요청만 허용됩니다." }, 405);

  try {
    const authorization = req.headers.get("Authorization") ?? "";
    const token = authorization.replace(/^Bearer\s+/i, "");
    if (!token) return json({ error: "로그인이 필요합니다." }, 401);

    const client = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authorization } } },
    );
    const { data: userData, error: userError } = await client.auth.getUser(token);
    const user = userData.user;
    if (userError || !user || user.is_anonymous || user.app_metadata?.herihub_role !== "admin") {
      return json({ error: "관리자 권한이 필요합니다." }, 403);
    }

    const body = await req.json().catch(() => ({}));
    const sourceId = typeof body.source_id === "string" ? body.source_id : "";
    if (!sourceId) return json({ error: "블로그 소스를 선택해 주세요." }, 400);

    const { data: source, error: sourceError } = await client.schema("herihub").from("blog_sources")
      .select("id,name,blog_id,rss_url,enabled").eq("id", sourceId).eq("enabled", true).single();
    if (sourceError || !source) return json({ error: "사용 가능한 블로그 소스를 찾지 못했습니다." }, 404);

    const rssResponse = await fetch(source.rss_url, {
      headers: { Accept: "application/rss+xml, application/xml, text/xml", "User-Agent": "DawaHub-RSS-Reader/1.0 (+https://dawahub.vercel.app)" },
      signal: AbortSignal.timeout(15000),
    });
    if (!rssResponse.ok) return json({ error: `RSS 응답 오류 (${rssResponse.status})` }, 502);

    const xml = await rssResponse.text();
    const parsed = new XMLParser({ ignoreAttributes: false, trimValues: true }).parse(xml);
    const rawItems = parsed?.rss?.channel?.item ?? [];
    const items = Array.isArray(rawItems) ? rawItems : [rawItems];
    const normalized = items.map((item: Record<string, unknown>) => {
      const description = asText(item.description);
      const imageMatch = description.match(/<img\b[^>]*\bsrc=["']([^"']+)["']/i);
      const originalUrl = asText(item.guid) || asText(item.link).split("?")[0];
      const externalId = originalUrl.split("/").filter(Boolean).pop() || originalUrl;
      const categories = Array.isArray(item.category) ? item.category.map(asText) : [asText(item.category)];
      const published = new Date(asText(item.pubDate));
      return {
        source_id: source.id,
        external_post_id: externalId.slice(0, 200),
        title: cleanText(asText(item.title)).slice(0, 200) || "제목 없는 글",
        category: categories.filter(Boolean).join(", ").slice(0, 200) || null,
        excerpt: cleanText(description).slice(0, 1200) || "원문에서 내용을 확인해 주세요.",
        original_url: originalUrl.slice(0, 500),
        thumbnail_url: imageMatch?.[1]?.replace(/^http:/, "https:").slice(0, 1000) || null,
        published_at: Number.isNaN(published.getTime()) ? null : published.toISOString(),
        fetched_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
    }).filter((item: Record<string, unknown>) => item.external_post_id && item.original_url);

    const { data: existing, error: existingError } = await client.schema("herihub").from("blog_posts")
      .select("external_post_id").eq("source_id", source.id);
    if (existingError) throw existingError;
    const existingIds = new Set((existing ?? []).map((item) => item.external_post_id));
    const fresh = normalized.filter((item: Record<string, unknown>) => !existingIds.has(item.external_post_id));
    if (fresh.length) {
      const { error: insertError } = await client.schema("herihub").from("blog_posts").insert(fresh);
      if (insertError) throw insertError;
    }

    const now = new Date().toISOString();
    const { error: updateError } = await client.schema("herihub").from("blog_sources")
      .update({ last_synced_at: now, updated_at: now }).eq("id", source.id);
    if (updateError) throw updateError;
    return json({ source: source.name, found: normalized.length, added: fresh.length, synced_at: now });
  } catch (error) {
    console.error(error);
    return json({ error: error instanceof Error ? error.message : "블로그 동기화 중 오류가 발생했습니다." }, 500);
  }
});
