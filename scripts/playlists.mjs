/** Shared playlist resolution for the CLI. Keep in sync with FoundationsTray.swift. */

export const MIX_TRACKS = [
  "system",
  "backend",
  "database",
  "dsa",
  "frontend",
  "network",
  "genai",
  "lang",
  "os",
  "arch",
  "tools",
];

export function playlistById(catalog, playlistId) {
  const lists = catalog.playlists ?? [];
  return lists.find((p) => p.id === playlistId) ?? lists.find((p) => p.id === "all") ?? { id: "all", title: "All plates" };
}

export function interleave(plates) {
  const groups = MIX_TRACKS.map((t) => plates.filter((p) => p.track === t)).filter((g) => g.length > 0);
  const out = [];
  for (let i = 0; ; i++) {
    let added = false;
    for (const g of groups) {
      if (i < g.length) {
        out.push(g[i]);
        added = true;
      }
    }
    if (!added) break;
  }
  return out;
}

export function playlistPlates(catalog, playlistId = "all") {
  const plates = catalog.plates;
  const pl = playlistById(catalog, playlistId);
  if (!pl || pl.id === "all") return plates;
  if (pl.mode === "interleave") return interleave(plates);
  if (pl.ids?.length) {
    const map = new Map(plates.map((p) => [p.id, p]));
    return pl.ids.map((id) => map.get(id)).filter(Boolean);
  }
  if (pl.tracks?.length) {
    const tracks = new Set(pl.tracks);
    return plates.filter((p) => tracks.has(p.track));
  }
  return plates;
}

export function stepPlaylist(catalog, playlistId, currentId, dir) {
  const list = playlistPlates(catalog, playlistId);
  if (list.length === 0) return catalog.plates[0];
  const i = list.findIndex((p) => p.id === currentId);
  if (i >= 0) {
    const n = list.length;
    return list[(i + dir + n) % n];
  }
  const full = catalog.plates.findIndex((p) => p.id === currentId);
  if (dir > 0) {
    return list.find((p) => catalog.plates.findIndex((x) => x.id === p.id) > full) ?? list[0];
  }
  for (let k = list.length - 1; k >= 0; k--) {
    if (catalog.plates.findIndex((x) => x.id === list[k].id) < full) return list[k];
  }
  return list[list.length - 1];
}
