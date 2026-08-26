# Foundations

Glanceable **computer science and software-engineering** posters as macOS wallpapers.

Each plate is HTML/CSS (not an image model), screenshotted at 14" Retina (`3024×1964`), then set as the desktop. A small menu-bar app walks the set in order, by playlist, on a timer.

Repo: [naseebpanghal1434/foundations-wallpapers](https://github.com/naseebpanghal1434/foundations-wallpapers) (private).

---

## How it works

```
posters/*.html  +  posters/assets/poster.css
        │
        ▼  npm run render -- --mbp14     (~8–12 min, Playwright)
output/mbp14/<id>.png                    (~1.1 GB, not in git)
        │
        ▼  npm run tray / npm run wallpaper
macOS desktop  +  Foundations menu-bar app
```

1. **Author** a plate as HTML (shared visual system in `poster.css`).
2. **Render** it to a PNG with Playwright.
3. **Set** it as wallpaper from the CLI or the tray.
4. **Rotate** with Next / Prev / Auto-advance inside a **playlist**.

The Swift app is compiled **on each Mac**. It embeds that machine’s folder path, so you never copy `Foundations.app` between computers.

---

## What is in git vs what you build

| In GitHub | Built on each Mac |
|---|---|
| `catalog.json` (375 plates + 20 playlists) | `output/mbp14/*.png` — wallpapers |
| `posters/` — HTML + CSS | `node_modules/` |
| `scripts/` — render, wallpaper, tray | `app/Foundations.app/` |
| `app/FoundationsTray.swift`, `app/Info.plist` | `app/GeneratedRoot.swift` (path) |
| `package.json` | `.current-plate`, `.tray-state.json` |

Git does **not** contain the PNGs. After clone you either:

- **Render** them (`npm run render -- --mbp14`), or
- **Copy** `output/mbp14/` from another Mac (USB / AirDrop) to skip render.

You still always run `npm run tray` on that Mac.

---

## Requirements

- macOS **13+**
- **Node 20+** (`node -v`)
- **Xcode Command Line Tools** (`swiftc` — `xcode-select --install`)
- **git**
- GitHub access to this **private** repo (`gh auth login`, or HTTPS with your account)

Optional: Playwright Chromium, only needed to render PNGs.

---

## First-time setup (other Mac)

```bash
# 1. Toolchain
xcode-select --install
# Install Node 20+ from https://nodejs.org if needed

# 2. Clone (private repo — sign in if git asks)
gh auth login
git clone https://github.com/naseebpanghal1434/foundations-wallpapers.git
cd foundations-wallpapers

# 3. JS deps
npm install

# 4. Wallpapers (~8–12 min). Skip if you copied output/mbp14/ already.
npx playwright install chromium
npm run render -- --mbp14

# 5. Menu-bar app for THIS folder
npm run tray

# 6. First desktop
npm run wallpaper -- 1
```

**Time:** Playwright download first time ~1–3 min. Render 375 plates ~8–12 min. Tray build a few seconds.

Leave the lid open until render finishes.

### Gatekeeper (unsigned app)

First launch of `app/Foundations.app` may be blocked:

- Right-click the app → **Open**, or
- System Settings → Privacy & Security → **Open Anyway**

Wallpaper changes may ask for **Automation** (System Events). Allow it.

---

## Daily use

The **Foundations** icon lives in the menu bar (layers symbol). Keep that process running; Quit stops rotation.

| Menu | What it does |
|---|---|
| **Next plate** (`⌘N` while the menu is open) | Next item in the **current playlist** |
| **Previous plate** | Previous in the playlist |
| **Plates** | Jump to a plate (list is the current playlist) |
| **Playlist** | Restrict Next / Prev / auto-advance to a subset |
| **Auto-advance** | Off, every 5 / 15 / 30 min, 1 / 2 / 6 h, daily at 9:00 |
| **Open at login** | Start the tray at login (unsigned apps may need a Security click) |
| **Quit Foundations** | Stops the timer |

Suggested: **Playlist → CS foundations** or **SDE-2**, then **Auto-advance → Every 15 minutes**.

### CLI (same playlist as the tray)

```bash
npm run wallpaper -- 1          # plate number
npm run wallpaper -- 308        # architecture latency plate
npm run next
npm run prev
npm run wallpaper -- status     # current id, title, playlist
npm run preview                 # HTML gallery at http://127.0.0.1:4173/
```

After **move or rename** of the folder:

```bash
npm run tray                    # rebuilds with the new absolute path
```

---

## Playlists

Next / Prev / Auto-advance only walk the selected playlist.

| Playlist | Plates | Contents |
|---|---|---|
| All plates | 375 | Entire catalog |
| CS foundations | 36 | OS + CPU / memory / encoding |
| Operating systems | 20 | Syscalls, pages, fork/CoW, epoll, cgroups |
| Architecture | 16 | Cache hierarchy, IEEE 754, SIMD, UTF-8 |
| Languages & runtime | 21 | AOT/JIT, ABI, UB, memory order |
| Unix & tools | 12 | Git objects, Make, `.so`, containers, strace |
| SDE-1 | 170 | DSA + language + frontend |
| SDE-2 | 177 | Systems + GenAI + OS (no DSA) |
| Interview mix | 375 | All tracks, round-robin |
| DSA | 116 | Data structures and interview patterns |
| Frontend + JS | 54 | Browser, React, JS runtime |
| GenAI | 30 | Tokens, RAG, agents, evals, cost |
| SDE-2 systems | 127 | Network, database, backend, system design |
| Backend | 42 | HTTP, auth, jobs, caches |
| Database | 33 | Indexes, MVCC, WAL, Postgres internals |
| Network | 20 | HTTP/2–3, TLS, DNS, TCP |
| System design | 26 | Rate limiter, chat, feed, outbox, … |
| Security | 28 | XSS, CSRF, JWT, SSRF, CSP, cookies |
| Concurrency | 14 | Races, mutexes, scheduling, atomics |
| Numbers & encoding | 5 | Endian, two’s complement, float, UTF-8/16 |

Playlists are defined in `catalog.json` (`tracks`, `mode: interleave`, or explicit `ids`).

---

## What’s on the plates

**375 posters.** Left-weighted layout (menu bar / notch / Dock / windows on the right). Shared look: kicker, title, lede, diagram, **What / Why / Trap**.

Tracks (also used for color):

| Track | Count | Range (typical) |
|---|---|---|
| DSA | 116 | 49–64, 101–200 |
| Backend | 42 | pools, auth, jobs, security extras |
| Frontend | 33 | 23–28, 226–251 |
| Database | 33 | indexes through B+ / VACUUM |
| System | 32 | CAP, CDN, design set 201–225 |
| GenAI | 30 | 12, 21–22, 44–48, 252–273 |
| Lang | 21 | OOP, memory, JIT, ABI |
| Network | 20 | HTTP/TCP through HTTP/3 |
| OS | 20 | 287–306 |
| Arch | 16 | 307–322 |
| Tools | 12 | 364–375 |

Numbers are the plate id prefix (`308-latency-hierarchy` → `npm run wallpaper -- 308`).

Each plate is **code**, not a generated image: diagrams are HTML/CSS so cache-line sizes, syscalls, and SQL stay exact.

---

## Commands

| Command | Purpose |
|---|---|
| `npm install` | Install Playwright |
| `npx playwright install chromium` | Browser used for screenshots |
| `npm run render -- --mbp14` | All plates → `output/mbp14/` |
| `npm run render -- --mbp14 --from=287` | From plate 287 onward |
| `npm run render -- --mbp14 --from=1 --to=20` | Inclusive numeric range |
| `npm run render -- --mbp14 74` | One plate (id prefix or substring) |
| `npm run render -- --16x10` | `2880×1800` |
| `npm run render -- --5k` | `5120×2880` |
| `npm run wallpaper -- N` | Set desktop to plate N |
| `npm run next` / `npm run prev` | Walk current playlist |
| `npm run wallpaper -- status` | Print current plate + playlist |
| `npm run preview` | Serve `posters/` on port 4173 |
| `npm run tray` | Compile + relaunch menu-bar app |
| `npm run tray:build` | Compile only |

Render time is about **1.5–1.6 s per plate** on a 14" M-series Mac (~10 min for 375).

---

## Repo layout

```
catalog.json                 # plates + playlists (source of truth)
package.json
posters/
  01-….html … 375-….html
  assets/poster.css          # shared visual system
  index.html                 # HTML index of all plates
scripts/
  render.mjs                 # Playwright export
  set-wallpaper.mjs          # osascript desktop + playlist
  playlists.mjs              # playlist resolution (CLI)
  build-tray.mjs             # swiftc → Foundations.app
  preview.mjs
app/
  FoundationsTray.swift      # menu bar
  Info.plist
  GeneratedRoot.swift        # generated, gitignored
  Foundations.app/           # generated, gitignored
output/mbp14/                # generated PNGs, gitignored
```

---

## Updating from GitHub

On the machine where you edit:

```bash
git add -A
git commit -m "Describe the change"
git push
```

On the other Mac:

```bash
git pull
npm run render -- --mbp14       # if posters or CSS changed
npm run tray                    # if Swift / tray changed, or you moved the folder
```

To render **only new plates** after a pull (example: ids 376+):

```bash
npm run render -- --mbp14 --from=376
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Missing image for …` | Run `npm run render -- --mbp14` or copy `output/mbp14/` |
| Tray shows old plates | `git pull` then `npm run tray` |
| Wallpaper does not change | Allow Automation for System Events; keep Foundations running |
| App blocked | Right-click → Open |
| Tray opens the **wrong folder** | You moved the project; `npm run tray` again |
| `swiftc: error` | `xcode-select --install` |
| Clone denied | Private repo: `gh auth login` |
| Render killed mid-way | Re-run the same command; it overwrites per plate |
| Folder name with a trailing space | Fine on the original Mac; you can clone as `foundations-wallpapers` elsewhere |

---

## Adding a plate (optional)

1. Add `posters/NNN-slug.html` using an existing plate as chrome (`data-track`, kicker, What / Why / Trap).
2. Append `{ "id", "track", "title" }` to `catalog.json`.
3. `npm run render -- --mbp14 NNN`
4. `npm run wallpaper -- NNN`

Tracks with colors in `poster.css`: `network`, `database`, `backend`, `system`, `genai`, `frontend`, `dsa`, `lang`, `os`, `arch`, `tools`.

Designed for leftover desktop: content sits left; the right stays empty for windows.
