import http from "node:http";
import { createHash, timingSafeEqual, randomBytes } from "node:crypto";
import { readFile, open, rename, unlink } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import path from "node:path";

const tokenPattern = /^[\w.-]{50,120}$/;

export async function installToken(file, token) {
  const temporary = path.join(path.dirname(file), `.bot-${randomBytes(12).toString("hex")}.tmp`);
  const handle = await open(temporary, "wx", 0o600);
  try {
    await handle.writeFile(`${token}\n`);
    await handle.chmod(0o600);
    await handle.sync();
    await handle.close();
    await rename(temporary, file);
  } finally {
    await handle.close().catch(() => {});
    await unlink(temporary).catch(() => {});
  }
}

export async function checkBotToken(token, fetchImpl = fetch) {
  const response = await fetchImpl("https://discord.com/api/v10/users/@me", {
    headers: { Authorization: `Bot ${token}` },
    redirect: "error",
    signal: AbortSignal.timeout(15000)
  });
  const data = await response.json().catch(() => null);
  if (!response.ok || !data?.id || !data?.bot) return { error: "Discord didn't accept that token." };
  return { name: String(data.username).slice(0, 40) };
}

export async function createSetupServer({ route, tokenHash, expiresAt, keyFile, check = checkBotToken, save = installToken, complete = () => {}, now = Date.now, host = "ivy.rest" }) {
  if (!/^\/[a-z\d-]{20,80}$/.test(route) || !/^[a-f\d]{64}$/.test(tokenHash) || !Number.isFinite(expiresAt)) throw new Error("invalid setup configuration");
  const expected = Buffer.from(tokenHash, "hex");
  const assets = new Map(await Promise.all([
    ["/", "index.html", "text/html; charset=utf-8"],
    ["/client.js", "client.js", "text/javascript; charset=utf-8"],
    ["/style.css", "style.css", "text/css; charset=utf-8"]
  ].map(async ([url, file, type]) => [url, { body: await readFile(new URL(`./public/${file}`, import.meta.url)), type }])));
  let used = false;
  let busy = false;
  let attempts = 0;
  let requests = 0;
  let windowStart = now();
  const server = http.createServer({ maxHeaderSize: 8192, headersTimeout: 5000, requestTimeout: 60000 }, (request, response) => {
    response.setHeader("Cache-Control", "private, no-store, max-age=0");
    response.setHeader("Referrer-Policy", "no-referrer");
    response.setHeader("X-Content-Type-Options", "nosniff");
    response.setHeader("X-Frame-Options", "DENY");
    response.setHeader("X-Robots-Tag", "noindex, nofollow, noarchive");
    response.setHeader("Content-Security-Policy", "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'");
    const reply = (status, message) => {
      if (response.headersSent) return;
      response.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
      response.end(JSON.stringify({ message }));
    };
    if (now() - windowStart >= 60000) { windowStart = now(); requests = 0; }
    if (++requests > 120) return reply(429, "Try again in a minute.");
    if (used || now() >= expiresAt || request.headers.host !== host) return reply(404, "Not found");
    const relative = request.url === route ? "/" : request.url.startsWith(`${route}/`) ? request.url.slice(route.length) : "";
    if (request.method === "GET" && assets.has(relative)) {
      const asset = assets.get(relative);
      response.writeHead(200, { "Content-Type": asset.type });
      return response.end(asset.type.startsWith("text/") ? asset.body.toString().replaceAll("__ROUTE__", route) : asset.body);
    }
    if (request.method !== "POST" || relative !== "/") return reply(404, "Not found");
    if (request.headers.origin !== `https://${host}` || request.headers["content-type"] !== "application/json") return reply(403, "Request denied");
    const authorization = request.headers.authorization || "";
    if (!/^Bearer [A-Za-z\d_-]{43}$/.test(authorization) || !timingSafeEqual(expected, createHash("sha256").update(authorization.slice(7)).digest())) return reply(404, "Not found");
    if (busy) return reply(409, "Already checking, wait a moment.");
    if (attempts >= 20) return reply(429, "This link has reached its attempt limit.");
    busy = true;
    attempts++;
    void (async () => {
      let body = "";
      let size = 0;
      for await (const chunk of request) {
        size += chunk.length;
        if (size > 2048) return reply(413, "That is too long.");
        body += chunk;
      }
      let input;
      try { input = JSON.parse(body); } catch { return reply(400, "Paste the bot token."); }
      const token = typeof input?.token === "string" ? input.token.trim() : "";
      if (!tokenPattern.test(token)) return reply(400, "That doesn't look like a Discord bot token.");
      const checked = await check(token);
      if (checked.error) return reply(400, checked.error);
      if (now() >= expiresAt) return reply(410, "This link has expired.");
      await save(keyFile, token);
      used = true;
      expected.fill(0);
      reply(200, `Saved. Connected as ${checked.name}. This page is now gone for good.`);
      complete();
    })().catch(() => reply(503, "Couldn't reach Discord. Try again shortly.")).finally(() => { busy = false; });
  });
  server.maxConnections = 16;
  server.keepAliveTimeout = 1000;
  server.timeout = 60000;
  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const config = JSON.parse(await readFile(process.argv[2], "utf8"));
  let closing = false;
  const stop = () => {
    if (closing) return;
    closing = true;
    server.close(() => process.exit(0));
    server.closeIdleConnections();
    setTimeout(() => process.exit(0), 2000).unref();
  };
  const server = await createSetupServer({ ...config, keyFile: "/etc/fiordland/bot.token", complete: stop });
  server.listen(3719, "127.0.0.1");
  setTimeout(stop, Math.max(1, config.expiresAt - Date.now())).unref();
  process.on("SIGTERM", stop);
  process.on("SIGINT", stop);
}
