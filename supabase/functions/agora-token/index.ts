import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { RtcRole, RtcTokenBuilder } from "npm:agora-access-token@2.0.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const body = await request.json();
    const channelName = String(body.channelName ?? "").trim();
    const uid = Number(body.uid ?? 0);
    if (!channelName || channelName.length > 64 || !/^[A-Za-z0-9_\-:.]+$/.test(channelName)) {
      return json({ error: "Invalid channelName" }, 400);
    }
    if (!Number.isInteger(uid) || uid < 0) return json({ error: "Invalid uid" }, 400);

    const appId = Deno.env.get("AGORA_APP_ID") ?? Deno.env.get("APP_ID");
    const appCertificate =
      Deno.env.get("AGORA_APP_CERTIFICATE") ??
      Deno.env.get("AGORA_APP_CERT") ??
      Deno.env.get("APP_CERTIFICATE");
    if (!appId || !appCertificate) {
      console.error("Agora secrets are not configured");
      return json({ error: "Agora is not configured" }, 500);
    }

    const now = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = now + 60 * 60;
    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      uid,
      RtcRole.PUBLISHER,
      privilegeExpiredTs,
      privilegeExpiredTs,
    );
    return json({ appId, token, channelName, uid, expiresAt: privilegeExpiredTs });
  } catch (error) {
    console.error(error);
    return json({ error: "Invalid request" }, 400);
  }
});
