import { createClient } from 'npm:@supabase/supabase-js@2';
import { generateToken04 } from './zegoServerAssistant.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) return json({ error: 'not_authenticated' }, 401);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return json({ error: 'not_authenticated' }, 401);

    const body = await req.json().catch(() => ({}));
    const roomId = String(body.roomId ?? '').trim();
    if (!/^[A-Za-z0-9_-]{1,64}$/.test(roomId)) return json({ error: 'invalid_room_id' }, 400);

    const { data: room, error: roomError } = await supabase
      .from('rooms')
      .select('id,room_id,owner_id,name,is_active')
      .eq('room_id', roomId)
      .eq('is_active', true)
      .maybeSingle();
    if (roomError || !room) return json({ error: 'room_not_found' }, 404);

    const appId = Number(Deno.env.get('ZEGO_APP_ID'));
    const serverSecret = Deno.env.get('ZEGO_SERVER_SECRET') ?? '';
    if (!appId || serverSecret.length !== 32) return json({ error: 'zego_secrets_not_configured' }, 500);

    const userName = String(body.userName ?? user.email?.split('@')[0] ?? user.id).slice(0, 64);
    const token = generateToken04(appId, user.id.replace(/[^A-Za-z0-9_]/g, '_'), serverSecret, 3600);
    return json({
      token,
      appId,
      roomId,
      userId: user.id,
      userName,
      isOwner: room.owner_id === user.id,
      roomName: room.name,
    });
  } catch (error) {
    console.error(error);
    return json({ error: 'token_generation_failed' }, 500);
  }
});
