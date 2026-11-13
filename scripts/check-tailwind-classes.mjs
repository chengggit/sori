import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

const sourceRoot = path.resolve("src");
const extensions = new Set([".svelte", ".ts", ".js"]);
const canonicalClasses = new Map([
  ["break-words", "wrap-break-word"],
]);

async function sourceFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await sourceFiles(entryPath)));
    } else if (extensions.has(path.extname(entry.name))) {
      files.push(entryPath);
    }
  }

  return files;
}

const findings = [];
for (const file of await sourceFiles(sourceRoot)) {
  const contents = await readFile(file, "utf8");
  for (const [legacyClass, canonicalClass] of canonicalClasses) {
    if (contents.includes(legacyClass)) {
      findings.push(path.relative(process.cwd(), file) + " uses " + legacyClass + ". Use " + canonicalClass + ".");
    }
  }
}

if (findings.length) {
  console.error(findings.join("\n"));
  process.exitCode = 1;
} else {
  console.log("Tailwind canonical class check passed.");
}
