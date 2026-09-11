import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const body = await req.json();
    const query = String(body.query ?? "").trim();
    const maxResults = Math.min(Math.max(Number(body.maxResults ?? 8), 1), 10);
    const key = Deno.env.get("YOUTUBE_API_KEY");
    if (!key) throw new Error("YOUTUBE_API_KEY is not configured");
    if (!query) return new Response(JSON.stringify({ items: [] }), { headers: { ...cors, "Content-Type": "application/json" } });
    const url = new URL("https://www.googleapis.com/youtube/v3/search");
    url.searchParams.set("part", "snippet");
    url.searchParams.set("type", "video");
    url.searchParams.set("videoEmbeddable", "true");
    url.searchParams.set("maxResults", String(maxResults));
    url.searchParams.set("q", query);
    url.searchParams.set("key", key);
    const result = await fetch(url);
    const json = await result.json();
    if (!result.ok) throw new Error(json?.error?.message ?? "YouTube search failed");
    const items = (json.items ?? []).map((item: any) => ({
      videoId: item.id?.videoId,
      title: item.snippet?.title ?? "YouTube",
      channelTitle: item.snippet?.channelTitle ?? "",
      thumbnail: item.snippet?.thumbnails?.medium?.url ?? item.snippet?.thumbnails?.default?.url,
    })).filter((item: any) => item.videoId);
    return new Response(JSON.stringify({ items }), { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error?.message ?? error) }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
