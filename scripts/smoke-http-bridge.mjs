import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

// Force immediate connection failures through a closed loopback proxy. This
// exercises real blocking HTTP client creation without contacting live services,
// using API keys, or opening a library database.
for (const name of [
  "HTTP_PROXY",
  "HTTPS_PROXY",
  "ALL_PROXY",
  "http_proxy",
  "https_proxy",
  "all_proxy",
]) {
  process.env[name] = "http://127.0.0.1:1";
}
process.env.NO_PROXY = process.env.no_proxy = "";
const require = createRequire(import.meta.url);
const addon = require(fileURLToPath(new URL("../native/sori-node.node", import.meta.url)));
for (let attempt = 0; attempt < 2; attempt++) {
  for (const [command, payload, expected] of [
    ["youtube:metadata", { id: "abcdefghijk" }, /Could not reach YouTube/],
    [
      "dictionary:lookup",
      { term: "학교", provider: "wiktionary" },
      /Wiktionary|request|connect|sending/i,
    ],
  ]) {
    const reply = JSON.parse(await addon.invoke(command, JSON.stringify(payload)));
    assert.equal(reply.ok, false);
    assert.equal(reply.data, null);
    assert.match(reply.error, expected);
    assert.doesNotMatch(reply.error, /runtime|panick|blocking is not allowed/i);
  }
}
assert.equal(JSON.parse(await addon.invoke("app:ping", "{}")).data, "pong");
console.log("HTTP bridge smoke: blocking clients return normal failures without async runtime panics.");
