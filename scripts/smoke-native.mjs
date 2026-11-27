import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const require = createRequire(import.meta.url);
const addon = require(join(root, "native", "sori-node.node"));

addon.init(join(root, "resources", "kiwi"));

async function analyze(text) {
  const reply = JSON.parse(await addon.invoke("analyzeText", JSON.stringify({ text })));
  if (!reply.ok) throw new Error(`analyzeText failed: ${reply.error}`);
  return reply.data;
}

function expect(condition, message) {
  if (!condition) throw new Error(message);
}

// Test vectors from core/src/nlp.rs in the Qt codebase.
const basic = await analyze("마음만큼은");
expect(
  JSON.stringify(basic.map((token) => token.form)) === JSON.stringify(["마음", "만큼", "은"]),
  "Unexpected morpheme forms.",
);
expect(
  JSON.stringify(basic.map((token) => token.tag)) === JSON.stringify(["NNG", "JKB", "JX"]),
  "Unexpected POS tags.",
);

const emoji = "😀 학교에 갔어요.";
const offsets = await analyze(emoji);
const school = offsets.find((token) => token.form === "학교");
expect(school?.start === 3, "UTF-16 offsets must treat the emoji as two units.");
expect(
  school.surface === emoji.slice(school.start, school.end),
  "Surface must match the original UTF-16 slice.",
);

const oversized = JSON.parse(
  await addon.invoke("analyzeText", JSON.stringify({ text: "a".repeat(16 * 1024 + 1) })),
);
expect(!oversized.ok && oversized.error.includes("16 KiB"), "16 KiB limit is not enforced.");

console.log(basic.map((token) => `${token.form}/${token.tag}`).join(" "));
