import { execFile } from "node:child_process";
import { promisify } from "node:util";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const exec = promisify(execFile);
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");
const appDir = path.join(root, "app", "Foundations.app", "Contents");
const macOS = path.join(appDir, "MacOS");
const binary = path.join(macOS, "Foundations");
const escaped = root.replaceAll("\\", "\\\\").replaceAll("\"", "\\\"");

await fs.mkdir(macOS, { recursive: true });
await fs.writeFile(
  path.join(root, "app", "GeneratedRoot.swift"),
  `enum FoundationsRoot {\n  static let path = "${escaped}"\n}\n`
);
await fs.copyFile(path.join(root, "app", "Info.plist"), path.join(appDir, "Info.plist"));

await exec("swiftc", [
  "-O",
  "-framework",
  "Cocoa",
  "-framework",
  "ServiceManagement",
  "-o",
  binary,
  path.join(root, "app", "FoundationsTray.swift"),
  path.join(root, "app", "GeneratedRoot.swift"),
]);

await fs.chmod(binary, 0o755);
console.log(`Built ${path.relative(root, binary)}`);
