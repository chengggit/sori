import { createHash } from "node:crypto";
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const releaseDirectory = join(root, "apps", "desktop", "release");
const artifacts = readdirSync(releaseDirectory)
  .filter((name) => /\.(AppImage|exe|dmg)$/.test(name))
  .sort();

const lines = artifacts.map((name) => {
  const hash = createHash("sha256")
    .update(readFileSync(join(releaseDirectory, name)))
    .digest("hex");
  return `${hash}  ${name}`;
});

writeFileSync(join(releaseDirectory, "SHA256SUMS.txt"), `${lines.join("\n")}\n`);
console.log(`Wrote SHA256SUMS.txt for ${artifacts.length} artifact(s).`);
