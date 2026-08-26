import { execFile } from "node:child_process";
import http from "node:http";
import { createReadStream, existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const postersDir = path.join(__dirname, "..", "posters");

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".svg": "image/svg+xml",
};

const server = http.createServer((req, res) => {
  const url = new URL(req.url, "http://127.0.0.1");
  const rel = decodeURIComponent(url.pathname);
  const file = path.normalize(path.join(postersDir, rel === "/" ? "index.html" : rel));
  if (!file.startsWith(postersDir) || !existsSync(file)) {
    res.writeHead(404).end("not found");
    return;
  }
  res.writeHead(200, { "Content-Type": MIME[path.extname(file)] ?? "application/octet-stream" });
  createReadStream(file).pipe(res);
});

server.listen(4173, "127.0.0.1", () => {
  const origin = "http://127.0.0.1:4173/";
  console.log(`Preview ${origin}`);
  execFile("open", [origin], () => {});
});
