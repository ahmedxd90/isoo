import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { RtcRole, RtcTokenBuilder } from "npm:agora-token@2.0.5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const tokenTtlSeconds = 60 * 60;
const appId = Deno.env.get("AGORA_APP_ID") ?? "";
const appCertificate = Deno.env.get("AGORA_APP_CERTIFICATE") ?? "";

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isValidChannelName(value: unknown): value is string {
  return typeof value === "string" && /^[a-f0-9-]{36}$/i.test(value);
}

function numericUid(userId: string): number {
  const prefix = userId.replaceAll("-", "").slice(0, 8);
  return Number.parseInt(prefix, 16) & 0x7fffffff;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "not_authenticated" }, 401);
  }
  if (!appId || !appCertificate) {
    return json({ error: "agora_server_not_configured" }, 500);
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authorization } } },
    );
    const { data: authData, error: authError } = await supabase.auth.getUser();
    const user = authData.user;
    if (authError || !user) return json({ error: "not_authenticated" }, 401);

    const body = await request.json().catch(() => ({}));
    const channelName = body?.channelName;
    if (!isValidChannelName(channelName)) {
      return json({ error: "invalid_channel_name" }, 400);
    }

    const uid = numericUid(user.id);
    if (body?.uid != null && Number(body.uid) !== uid) {
      return json({ error: "uid_mismatch" }, 403);
    }

    const { data: room, error: roomError } = await supabase
      .from("rooms")
      .select("id,owner_id,is_active")
      .eq("id", channelName)
      .eq("is_active", true)
      .maybeSingle();
    if (roomError || !room) return json({ error: "room_not_found" }, 404);

    const { data: membership, error: membershipError } = await supabase
      .from("room_members")
      .select("user_id")
      .eq("room_id", channelName)
      .eq("user_id", user.id)
      .maybeSingle();
    if (membershipError) return json({ error: "room_membership_check_failed" }, 403);
    if (!membership && room.owner_id !== user.id) {
      return json({ error: "room_member_required" }, 403);
    }

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      uid,
      RtcRole.PUBLISHER,
      tokenTtlSeconds,
      tokenTtlSeconds,
    );
    return json({ token, appId, channelName, uid, expiresIn: tokenTtlSeconds });
  } catch (error) {
    console.error("agora-token failed", error);
    return json({ error: "token_generation_failed" }, 500);
  }
});
