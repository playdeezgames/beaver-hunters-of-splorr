#!/usr/bin/env node
// Writes assets/screenshots/*.png from the real build: headless Chrome driven over the DevTools protocol, in real
// time, through the page's screenshot hooks (?speed=N runs the game clock N times fast; ?keys=Code@ms presses keys
// once the game is running; see web/index.html). Each shot starts from an empty save (its own throwaway profile).
// The canvas is saved at 2x (1280 by 720), nearest-neighbour. Run ./build.sh first. Rerun after any change to the
// trip text so the play shots show the real lines. Usage: node tools/make_screenshots.mjs
import { spawn } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const PORT = 8152, DEBUG = 9333;
const OUT = join(ROOT, "assets", "screenshots");
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// H every 500 ms from a to b (presses during a trip are ignored)
const hunts = (a, b) => { const k = []; for (let t = a; t < b; t += 500) k.push(`KeyH@${t}`); return k; };

const SHOTS = [ // name, keys, real ms to wait (game time is 10x)
  ["01-title", [], 1500],
  ["02-first-trip", ["Enter@300", ...hunts(600, 1200)], 1500],
  ["03-hands", ["Enter@300", ...hunts(600, 30000), "KeyS@30100", "KeyS@30300", ...hunts(30500, 34000)], 34500],
  ["04-credits", ["KeyC@300"], 1500],
];

const server = spawn("python3", ["-m", "http.server", String(PORT), "-d", join(ROOT, "build", "web")], { stdio: "ignore" });
const profile = mkdtempSync(join(tmpdir(), "bhos-shots-"));
const chrome = spawn("google-chrome", ["--headless=new", "--no-sandbox", "--disable-gpu", `--remote-debugging-port=${DEBUG}`,
  `--user-data-dir=${profile}`, "--window-size=1280,800", "about:blank"], { stdio: "ignore" });
const cleanup = () => { chrome.kill(); server.kill(); rmSync(profile, { recursive: true, force: true }); };

try {
  await sleep(1500);
  mkdirSync(OUT, { recursive: true });
  for (const [name, keys, wait] of SHOTS) {
    const target = await (await fetch(`http://127.0.0.1:${DEBUG}/json/new?about:blank`, { method: "PUT" })).json();
    const ws = new WebSocket(target.webSocketDebuggerUrl);
    await new Promise((r) => ws.addEventListener("open", r, { once: true }));
    let id = 0; const pending = new Map();
    ws.addEventListener("message", (e) => { const m = JSON.parse(e.data); if (pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } });
    const send = (method, params = {}) => new Promise((r) => { pending.set(++id, r); ws.send(JSON.stringify({ id, method, params })); });
    // a fresh origin storage per shot: clear the save before the game reads it
    await send("Storage.clearDataForOrigin", { origin: `http://localhost:${PORT}`, storageTypes: "all" });
    await send("Page.navigate", { url: `http://localhost:${PORT}/?speed=10&keys=${keys.join(",")}` });
    await sleep(wait);
    const r = await send("Runtime.evaluate", { returnByValue: true, expression: `(() => {
      const s = document.getElementById("screen"), c = document.createElement("canvas");
      c.width = s.width * 2; c.height = s.height * 2;
      const g = c.getContext("2d"); g.imageSmoothingEnabled = false; g.drawImage(s, 0, 0, c.width, c.height);
      return c.toDataURL("image/png"); })()` });
    writeFileSync(join(OUT, `${name}.png`), Buffer.from(r.result.result.value.split(",")[1], "base64"));
    console.log(`assets/screenshots/${name}.png`);
    ws.close();
    await fetch(`http://127.0.0.1:${DEBUG}/json/close/${target.id}`);
  }
} finally { cleanup(); }
