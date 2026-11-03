// Sends a push notification to every phone of one user through Firebase Cloud
// Messaging (HTTP v1). Called only by the database (notify_push) with the
// x-push-secret header. Secret: FIREBASE_SERVICE_ACCOUNT (service account JSON);
// the shared password lives in the database vault (get_push_secret). Deploy with JWT verification OFF (the secret header protects it).
import { createClient } from "npm:@supabase/supabase-js@2";

const b64url = (d: ArrayBuffer | string) => {
  const bytes = typeof d === "string" ? new TextEncoder().encode(d) : new Uint8Array(d);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

async function accessToken(sa: { client_email: string; private_key: string }) {
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${head}.${claim}`));
  const jwt = `${head}.${claim}.${b64url(sig)}`;
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
  });
  const j = await r.json();
  if (!j.access_token) throw new Error("token: " + JSON.stringify(j));
  return j.access_token as string;
}

Deno.serve(async (req) => {
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: expected } = await sb.rpc("get_push_secret");
  const given = req.headers.get("x-push-secret");
  if (!expected || !given || given !== expected) {
    return new Response("forbidden", { status: 403 });
  }
  const saRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!saRaw) return new Response("no service account", { status: 500 });
  const { user_id, title, body } = await req.json();
  if (!user_id || !title) return new Response("bad request", { status: 400 });

  const { data: rows } = await sb.from("device_tokens").select("token").eq("user_id", user_id);
  if (!rows || rows.length === 0) return new Response("no devices", { status: 200 });

  const sa = JSON.parse(saRaw);
  const at = await accessToken(sa);
  let sent = 0;
  for (const { token } of rows) {
    const r = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
      method: "POST",
      headers: { Authorization: `Bearer ${at}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: String(title).slice(0, 80), body: String(body ?? "").slice(0, 200) },
          android: { priority: "HIGH", notification: { channel_id: "cheers" } },
        },
      }),
    });
    if (r.ok) sent++;
    else if (r.status === 404 || r.status === 400) {
      const t = await r.text();
      if (t.includes("UNREGISTERED") || t.includes("INVALID_ARGUMENT")) {
        await sb.from("device_tokens").delete().eq("token", token);
      }
    }
  }
  return new Response(JSON.stringify({ sent }), { headers: { "Content-Type": "application/json" } });
});
