import { spawnSync } from "node:child_process";
import { copyFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const release = process.argv.includes("--release");
const manifest = join(root, "crates", "Cargo.toml");
const args = ["build", "-p", "sori-node", "--manifest-path", manifest];
if (release) args.push("--release");

const build = spawnSync("cargo", args, { cwd: root, stdio: "inherit" });
if (build.status !== 0) process.exit(build.status ?? 1);

const target = join(root, "crates", "target", release ? "release" : "debug");
const library =
  process.platform === "win32"
    ? "sori_node.dll"
    : process.platform === "darwin"
      ? "libsori_node.dylib"
      : "libsori_node.so";
const destination = join(root, "native", "sori-node.node");

mkdirSync(dirname(destination), { recursive: true });
copyFileSync(join(target, library), destination);
console.log(`Native addon: ${destination}`);
