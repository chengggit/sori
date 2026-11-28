import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
const require = createRequire(import.meta.url);
const addon = require("../native/sori-node.node");
const ffmpeg = require("ffmpeg-static");
const { execFileSync } = await import("node:child_process");
const directory = mkdtempSync(join(tmpdir(), "sori-watch-native-"));
async function call(command, payload = {}) {
  const reply = JSON.parse(await addon.invoke(command, JSON.stringify(payload)));
  assert.equal(reply.ok, true, `${command}: ${reply.error}`);
  return reply.data;
}
try {
  addon.initLibrary(directory);
  const video = join(directory, "watch.mp4");
  execFileSync(ffmpeg, [
    "-v",
    "error",
    "-f",
    "lavfi",
    "-i",
    "color=c=blue:s=160x90:d=1",
    "-pix_fmt",
    "yuv420p",
    video,
  ]);
  await call("video:import", { path: video });
  const { videos } = await call("library:state");
  const txt = join(directory, "transcript.txt");
  const srt = join(directory, "captions.srt");
  writeFileSync(txt, "학교에 갔어요.\n한국어 공부");
  writeFileSync(srt, "1\n00:00:00,000 --> 00:00:01,000\n학교에 갔어요.\n");
  await call("video:saveSubtitles", { id: videos[0].id, path: srt });
  assert.match((await call("video:read", { id: videos[0].id })).sidecar, /학교/);
  for (const source of [
    { kind: "local", id: videos[0].id },
    { kind: "youtube", id: "dQw4w9WgXcQ" },
  ]) {
    await call("video:saveTranscript", { ...source, path: txt });
    await call("video:saveTranscriptPosition", { ...source, position: 0.6 });
    addon.initLibrary(directory);
    assert.equal((await call("video:readTranscript", source)).position, 0.6);
    const entry = await call("vocabulary:save", {
      ...source,
      title: "YouTube sample",
      input: { word: "학교", context: "학교에 갔어요.", tags: [] },
    });
    assert.equal(
      (await call("vocabulary:find", { ...source, word: "학교", context: "학교에 갔어요." })).id,
      entry.id,
    );
    writeFileSync(txt, "새로운 내용");
    assert.equal((await call("video:saveTranscript", { ...source, path: txt })).position, 0);
    await call("video:removeTranscript", source);
    assert.ok(!(await call("video:readTranscript", source)).content);
  }
  assert.match((await call("video:read", { id: videos[0].id })).sidecar, /학교/);
  console.log(
    "Watch native smoke: transcript persistence/replacement/removal, local/YouTube vocabulary and subtitle persistence passed.",
  );
} finally {
  rmSync(directory, { recursive: true, force: true });
}
