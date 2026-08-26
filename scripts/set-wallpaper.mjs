import { execFile } from "node:child_process";
import { promisify } from "node:util";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { playlistById, playlistPlates, stepPlaylist } from "./playlists.mjs";

const exec = promisify(execFile);
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..");
const catalog = JSON.parse(await fs.readFile(path.join(root, "catalog.json"), "utf8"));
const currentPath = path.join(root, ".current-plate");
const statePath = path.join(root, ".tray-state.json");

const args = process.argv.slice(2).filter((a) => a !== "--");
const sizePref = args.includes("--5k") ? "5k" : args.includes("--16x10") ? "16x10" : args.includes("--mbp14") ? "mbp14" : "mbp14";
const query = (args.find((a) => !a.startsWith("--")) ?? "").toLowerCase();

async function loadTrayState() {
  try {
    const s = JSON.parse(await fs.readFile(statePath, "utf8"));
    return { plateId: s.plateId ?? "", advance: s.advance ?? "off", playlist: s.playlist ?? "all" };
  } catch {
    let plateId = "";
    try {
      plateId = (await fs.readFile(currentPath, "utf8")).trim();
    } catch {
      /* empty */
    }
    return { plateId, advance: "off", playlist: "all" };
  }
}

async function saveTrayState(state) {
  await fs.writeFile(statePath, JSON.stringify(state), "utf8");
  if (state.plateId) await fs.writeFile(currentPath, state.plateId, "utf8");
}

function matchPlate(q) {
  const num = Number(q);
  return catalog.plates.find((p) => {
    const n = parseInt(p.id, 10);
    if (Number.isFinite(num) && num === n) return true;
    return p.id === q || p.id.startsWith(q) || p.id.includes(q);
  });
}

async function pickPlate() {
  const state = await loadTrayState();
  const playlistId = state.playlist || "all";
  const list = playlistPlates(catalog, playlistId);
  const currentId = state.plateId;

  if (query === "next" || query === "prev") {
    const dir = query === "next" ? 1 : -1;
    return { plate: stepPlaylist(catalog, playlistId, currentId, dir), state, playlistId };
  }
  if (query === "status" || query === "") {
    const plate = list.find((p) => p.id === currentId) ?? catalog.plates.find((p) => p.id === currentId) ?? list[0] ?? catalog.plates[0];
    return { plate, state, playlistId };
  }
  const found = matchPlate(query);
  if (!found) {
    console.error(`Unknown plate "${query}". Try: next | prev | 1…${catalog.plates.length}`);
    process.exit(1);
  }
  return { plate: found, state, playlistId };
}

async function resolveFile(plate) {
  const order = [sizePref, "mbp14", "16x10", "5k"];
  const unique = [...new Set(order)];
  for (const size of unique) {
    const file = path.resolve(root, "output", size, `${plate.id}.png`);
    try {
      await fs.access(file);
      return { file, size };
    } catch {
      /* try next */
    }
  }
  console.error(`Missing image for ${plate.id}\nRun: npm run render`);
  process.exit(1);
}

const { plate, state, playlistId } = await pickPlate();
const pl = playlistById(catalog, playlistId);

if (query === "status") {
  console.log(`${plate.id}  ${plate.title}`);
  console.log(`playlist  ${pl.id}  (${playlistPlates(catalog, playlistId).length} plates)`);
  process.exit(0);
}

const { file, size } = await resolveFile(plate);
const posix = file.replaceAll("\\", "/");
const script = `
tell application "System Events"
  set posixFile to POSIX file "${posix}"
  set desktopCount to count of desktops
  repeat with i from 1 to desktopCount
    tell desktop i
      set picture to posixFile
    end tell
  end repeat
end tell
`;

try {
  await exec("osascript", ["-e", script]);
} catch {
  await exec("osascript", [
    "-e",
    `tell application "Finder" to set desktop picture to POSIX file "${posix}"`,
  ]);
}

state.plateId = plate.id;
await saveTrayState(state);
console.log(`Wallpaper → ${plate.title}`);
console.log(`playlist  ${pl.title}`);
console.log(`${size}  ${file}`);
