import http from "node:http";
import fs from "node:fs/promises";
import { createReadStream, existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..");
const postersDir = path.join(root, "posters");
const outputDir = path.join(root, "output");

const SIZES = {
  "16x10": { width: 2880, height: 1800 },
  mbp14: { width: 3024, height: 1964 },
  "5k": { width: 5120, height: 2880 },
};

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".svg": "image/svg+xml",
  ".json": "application/json",
  ".woff2": "font/woff2",
};

function startServer() {
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, "http://127.0.0.1");
    const rel = decodeURIComponent(url.pathname);
    const file = path.normalize(path.join(postersDir, rel === "/" ? "index.html" : rel));
    if (!file.startsWith(postersDir)) {
      res.writeHead(403).end("forbidden");
      return;
    }
    if (!existsSync(file)) {
      res.writeHead(404).end("not found");
      return;
    }
    res.writeHead(200, { "Content-Type": MIME[path.extname(file)] ?? "application/octet-stream" });
    createReadStream(file).pipe(res);
  });
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      resolve({ server, origin: `http://127.0.0.1:${port}` });
    });
  });
}

async function waitForFonts(page) {
  await page.evaluate(async () => {
    await document.fonts.ready;
    const families = ["Big Shoulders Display", "IBM Plex Mono", "Fraunces"];
    await Promise.all(
      families.map((f) => document.fonts.load(`800 64px "${f}"`).catch(() => {}))
    );
  });
  await new Promise((r) => setTimeout(r, 200));
}

const catalog = JSON.parse(await fs.readFile(path.join(root, "catalog.json"), "utf8"));
const argv = process.argv.slice(2);
const only = argv.filter((a) => !a.startsWith("--"));
const fromArg = argv.find((a) => a.startsWith("--from="));
const toArg = argv.find((a) => a.startsWith("--to="));
const fromN = fromArg ? parseInt(fromArg.slice(7), 10) : 0;
const toN = toArg ? parseInt(toArg.slice(5), 10) : Infinity;
const sizeArg = argv.includes("--5k")
  ? ["5k"]
  : argv.includes("--16x10")
    ? ["16x10"]
    : argv.includes("--mbp14")
      ? ["mbp14"]
      : Object.keys(SIZES);

function plateNum(id) {
  const m = /^(\d+)/.exec(id);
  return m ? parseInt(m[1], 10) : NaN;
}

const plates = catalog.plates.filter((p) => {
  const n = plateNum(p.id);
  if (n < fromN || n > toN) return false;
  if (only.length === 0) return true;
  return only.some((q) => p.id.startsWith(q) || p.id.includes(q) || String(n) === q);
});

if (plates.length === 0) {
  console.error("No matching plates.");
  process.exit(1);
}

const { server, origin } = await startServer();
const browser = await chromium.launch();

try {
  for (const sizeName of sizeArg) {
    const size = SIZES[sizeName];
    const dir = path.join(outputDir, sizeName);
    await fs.mkdir(dir, { recursive: true });

    for (const plate of plates) {
      const page = await browser.newPage({
        viewport: size,
        deviceScaleFactor: 1,
      });
      const url = `${origin}/${plate.id}.html`;
      await page.goto(url, { waitUntil: "networkidle", timeout: 60_000 });
      await waitForFonts(page);
      const dest = path.join(dir, `${plate.id}.png`);
      await page.screenshot({ path: dest, type: "png" });
      await page.close();
      const stat = await fs.stat(dest);
      console.log(`${sizeName.padEnd(6)} ${plate.id}  ${(stat.size / 1024 / 1024).toFixed(1)} MB`);
    }
  }
} finally {
  await browser.close();
  server.close();
}
