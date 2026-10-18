import { createClient } from 'npm:@supabase/supabase-js@2';

const OPENAI_KEY = Deno.env.get('OPENAI_API_KEY') ?? '';
const ALLOWED_MODELS = new Set(['gpt-4.1', 'gpt-4.1-mini']);
const MAX_TOKENS_CAP = 1500;

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_ANON_KEY')!,
);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405);

  const token = req.headers.get('Authorization')?.replace('Bearer ', '') ?? '';
  const { data: { user } } = await supabase.auth.getUser(token);
  if (!user) return json({ error: 'unauthorized' }, 401);

  if (!OPENAI_KEY) return json({ error: 'server not configured' }, 500);

  const body = await req.json().catch(() => null);
  if (!body || !Array.isArray(body.messages)) return json({ error: 'invalid body' }, 400);

  const payload = {
    model: ALLOWED_MODELS.has(body.model) ? body.model : 'gpt-4.1',
    messages: body.messages,
    temperature: typeof body.temperature === 'number' ? body.temperature : 0.3,
    max_tokens: Math.min(Number(body.max_tokens) || 600, MAX_TOKENS_CAP),
  };

  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENAI_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  return new Response(await res.text(), {
    status: res.status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
});
