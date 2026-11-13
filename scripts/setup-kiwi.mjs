import { createHash } from "node:crypto";
import { createReadStream, createWriteStream } from "node:fs";
import { access, copyFile, cp, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";

const version = "0.24.0";
const target = `${process.platform}-${process.arch}`;
// SHA-256 digests published with the pinned upstream release.
const libraries = {
  "linux-x64": [
    "lnx_x86_64",
    "tgz",
    "libkiwi.so",
    "577768800258154da5fe6665081c73dafd6a0c39c8e091325d2b2bef8b5fb5d8",
  ],
  "linux-arm64": [
    "lnx_aarch64",
    "tgz",
    "libkiwi.so",
    "431fafce1bafc7bf5a4abcf7d306321df47cb4daabb9e8e16d40bb528a432fac",
  ],
  "darwin-x64": [
    "mac_x86_64",
    "tgz",
    "libkiwi.dylib",
    "98d64a1fd7acd409bb4b26889fa67355ed569e8be3568f731c3f3e27eb45a5f6",
  ],
  "darwin-arm64": [
    "mac_arm64",
    "tgz",
    "libkiwi.dylib",
    "87eda17f319c371824d5a2cc2e497eda6327ba3ddbf08a018db967f61ddbe48d",
  ],
  "win32-x64": [
    "win_x64",
    "zip",
    "kiwi.dll",
    "d876d04cfff71dd4042f6964e1b950378fcb306234ac0258c4020cd23d9c4204",
  ],
};
const selected = libraries[target];
if (!selected) throw new Error(`Kiwi setup does not support ${target}.`);
const [platform, extension, libraryName, libraryHash] = selected;
const destination = fileURLToPath(new URL("../src-tauri/resources/kiwi/", import.meta.url));
// Refresh notices even when the downloaded library and model are already cached.
await mkdir(destination, { recursive: true });
for (const name of ["Kiwi", "kiwi-rs"]) {
  await copyFile(
    fileURLToPath(new URL(`../src-tauri/third-party/${name}-LICENSE`, import.meta.url)),
    join(destination, `LICENSE-${name}`),
  );
}
const marker = join(destination, "ready.json");
try {
  const ready = JSON.parse(await readFile(marker, "utf8"));
  await access(join(destination, "lib", libraryName));
  await access(join(destination, "models", "cong", "base", "sj.morph"));
  await access(join(destination, "models", "cong", "base", "cong.mdl"));
  if (ready.version === version && ready.target === target) {
    console.log(`Kiwi ${version} resources already prepared for ${target}.`);
    process.exit(0);
  }
} catch {
  // Prepare missing or incomplete resources again.
}

async function download(name, expectedHash, directory) {
  const url = `https://github.com/bab2min/Kiwi/releases/download/v${version}/${name}`;
  console.log(`Downloading ${name}`);
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Download failed (${response.status}): ${url}`);
  const archive = join(directory, name);
  await pipeline(Readable.fromWeb(response.body), createWriteStream(archive));
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(archive)) hash.update(chunk);
  if (hash.digest("hex") !== expectedHash) throw new Error(`Checksum mismatch for ${name}`);
  const extraction = join(directory, name + "-extracted");
  await mkdir(extraction);
  const result = spawnSync("tar", ["-xf", archive, "-C", extraction], { stdio: "inherit" });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Could not extract ${name}. Install tar and retry.`);
  return extraction;
}

const temporary = await mkdtemp(join(tmpdir(), "sori-kiwi-"));
try {
  const native = await download(`kiwi_${platform}_v${version}.${extension}`, libraryHash, temporary);
  const model = await download(
    `kiwi_model_v${version}_base.tgz`,
    "33188ba932bba4717bad5244bbec0ef8b1c9cbb47e26e68394a7976d8d779083",
    temporary,
  );
  // An interrupted copy must be prepared again on the next setup run.
  await rm(marker, { force: true });
  await mkdir(join(destination, "lib"), { recursive: true });
  await copyFile(join(native, "lib", libraryName), join(destination, "lib", libraryName));
  await cp(join(model, "models"), join(destination, "models"), { recursive: true });
  await writeFile(marker, JSON.stringify({ version, target }, null, 2) + "\n");
  console.log(`Prepared Kiwi ${version} for ${target} in ${destination}`);
} finally {
  await rm(temporary, { recursive: true, force: true });
}
