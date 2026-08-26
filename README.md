# Foundations — CS / SDE wallpapers for macOS

HTML/CSS posters rendered to 14" Retina PNGs, set as the desktop, rotated from a menu-bar app.

The GitHub repo holds **source** (HTML, CSS, Swift, catalog). Wallpaper PNGs (~1.1 GB) are **not** in git — you render them on each Mac. The menu-bar app is compiled **on that Mac** so it points at that folder.

## Install on another Mac (clone + build)

Needs **macOS 13+**, **Node 20+**, **Xcode Command Line Tools** (`swiftc`), and **git**.

```bash
xcode-select --install          # if swiftc is missing
# Node 20+ from https://nodejs.org if `node -v` is too old

git clone https://github.com/naseebpanghal1434/foundations-wallpapers.git
cd foundations-wallpapers

npm install
npx playwright install chromium
npm run render -- --mbp14       # ~5–8 minutes, writes output/mbp14/
npm run tray                    # compiles Foundations.app for THIS path and opens it
npm run wallpaper -- 1
```

If the repo is **private**, GitHub will ask you to sign in (`gh auth login` or a personal access token).

## What is in git vs what is built locally

**Pushed**

- `catalog.json`, `posters/`, `scripts/`, `app/FoundationsTray.swift`, `app/Info.plist`, `package.json`

**Not pushed (generated on each Mac)**

- `output/` — wallpapers
- `node_modules/`
- `app/Foundations.app/` — unsigned binary bound to this machine’s folder path
- `app/GeneratedRoot.swift`
- `.current-plate`, `.tray-state.json`

## USB / AirDrop (optional)

You can still copy `output/mbp14/` onto the other Mac after clone to skip `npm run render`. Do not copy `Foundations.app`; always `npm run tray` on that machine.

Click the **Foundations** icon in the menu bar → **Plates**.

### Menu bar

- **Next / Prev** — walk the current playlist
- **Playlist** — DSA, SDE-1/2, CS foundations, OS, architecture, Frontend, GenAI, …
- **Auto-advance** — 5 min … daily at 9:00
- **Open at login** — keep rotating after reboot (unsigned app; see below)

The tray must keep running. Quit Foundations and rotation stops.

### Unsigned app (Gatekeeper)

The first `open` of `app/Foundations.app` may be blocked.

- System Settings → Privacy & Security → **Open Anyway**, or
- Right-click the app → Open

Wallpaper changes may prompt **Automation** access for System Events. Allow it.

## Useful commands

```bash
npm run wallpaper -- 308        # jump to a plate number
npm run next
npm run prev
npm run wallpaper -- status     # current plate + playlist
npm run tray                    # rebuild + relaunch after you move the folder
```

If you **rename or move** the folder, run `npm run tray` again. The app stores an absolute path at compile time.
