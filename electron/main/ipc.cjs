const { BrowserWindow, dialog, shell } = require("electron");
const { execFile } = require("node:child_process");
const { stat, readFile } = require("node:fs/promises");
const { basename } = require("node:path");
const { promisify } = require("node:util");
const { toolPath } = require("./runtime.cjs");
const {
  exposeVideo,
  currentMedia,
  videoExtensions,
  textCodecs,
  subtitleLimit,
} = require("./media.cjs");
const run = promisify(execFile);

module.exports = function registerIpc(handle, native) {
  handle("app:ping", () => ({ ok: true, data: "pong", error: "" }));
  handle("dialog:openDocument", async (event) => {
    const result = await dialog.showOpenDialog(BrowserWindow.fromWebContents(event.sender), {
      title: "Import a text or PDF file",
      properties: ["openFile"],
      filters: [
        { name: "Text and PDF files", extensions: ["txt", "pdf"] },
        { name: "Text files", extensions: ["txt"] },
        { name: "PDF files", extensions: ["pdf"] },
        { name: "All files", extensions: ["*"] },
      ],
    });
    if (result.canceled) return null;
    const path = result.filePaths[0];
    const extension = path.split(".").pop()?.toLowerCase();
    if (extension !== "txt" && extension !== "pdf") {
      throw new Error("Choose a .txt or .pdf file.");
    }
    return path;
  });
  handle("dialog:openVideo", async (event) => {
    const result = await dialog.showOpenDialog(BrowserWindow.fromWebContents(event.sender), {
      title: "Import a video",
      properties: ["openFile"],
      filters: [
        { name: "Video files", extensions: videoExtensions },
        { name: "All files", extensions: ["*"] },
      ],
    });
    return result.canceled ? null : result.filePaths[0];
  });
  handle("video:expose", async (_event, path) => {
    const record = await exposeVideo(path);
    return { id: record.id, url: record.url, name: basename(record.local) };
  });
  handle("video:probe", async (_event, id) => {
    const selected = currentMedia(id);
    try {
      const { stdout } = await run(
        toolPath("ffprobe"),
        [
          "-v",
          "error",
          "-protocol_whitelist",
          "file",
          "-format_whitelist",
          "mov,matroska,webm,avi,mpegts",
          "-show_entries",
          "format=format_name:stream=index,codec_type,codec_name:stream_tags=language,title",
          "-of",
          "json",
          "-i",
          selected.local,
        ],
        { maxBuffer: 1024 * 1024, timeout: 30000 },
      );
      const { format, streams = [] } = JSON.parse(stdout);
      return {
        container: format?.format_name ?? "",
        video: streams.find((stream) => stream.codec_type === "video")?.codec_name ?? "",
        audio: streams
          .filter((stream) => stream.codec_type === "audio")
          .map((stream) => stream.codec_name),
        tracks: streams
          .filter((stream) => stream.codec_type === "subtitle" && textCodecs.has(stream.codec_name))
          .map((stream) => ({
            index: stream.index,
            language: stream.tags?.language ?? "",
            label: [stream.tags?.title, stream.tags?.language, stream.codec_name]
              .filter(Boolean)
              .join(" · "),
          })),
      };
    } catch (error) {
      return {
        error:
          error.code === "ENOENT"
            ? "Install FFprobe to inspect embedded tracks."
            : "FFprobe could not read this file’s track information.",
      };
    }
  });
  handle("video:track", async (_event, id, index) => {
    const selected = currentMedia(id);
    const probe = await run(
      toolPath("ffprobe"),
      [
        "-v",
        "error",
        "-protocol_whitelist",
        "file",
        "-show_entries",
        "stream=index,codec_type,codec_name",
        "-of",
        "json",
        "-i",
        selected.local,
      ],
      { maxBuffer: 1024 * 1024, timeout: 30000 },
    )
      .then(({ stdout }) => JSON.parse(stdout))
      .catch(() => ({ streams: [] }));
    const track = (probe.streams ?? []).find(
      (stream) => stream.index === index && stream.codec_type === "subtitle",
    );
    if (!track) throw new Error("Choose a text subtitle track.");
    try {
      const { stdout } = await run(
        toolPath("ffmpeg"),
        [
          "-v",
          "error",
          "-nostdin",
          "-protocol_whitelist",
          "file",
          "-format_whitelist",
          "mov,matroska,webm,avi,mpegts",
          "-i",
          selected.local,
          "-map",
          `0:${index}`,
          "-c:s",
          "webvtt",
          "-f",
          "webvtt",
          "pipe:1",
        ],
        { maxBuffer: subtitleLimit, timeout: 45000 },
      );
      return stdout;
    } catch (error) {
      throw new Error(
        error.code === "ENOENT"
          ? "Install FFmpeg to extract embedded subtitles."
          : "FFmpeg could not extract this text track.",
      );
    }
  });
  handle("video:attach", async (event, id) => {
    currentMedia(id);
    const result = await dialog.showOpenDialog(BrowserWindow.fromWebContents(event.sender), {
      properties: ["openFile"],
      filters: [{ name: "Text subtitles", extensions: ["srt", "vtt"] }],
    });
    if (result.canceled) return null;
    currentMedia(id);
    const path = result.filePaths[0];
    const info = await stat(path);
    if (!info.isFile() || info.size > subtitleLimit) {
      throw new Error("Choose a subtitle file under 8 MiB.");
    }
    return {
      name: basename(path),
      text: new TextDecoder("utf-8", { fatal: true }).decode(await readFile(path)),
    };
  });
  handle("shell:openExternal", async (_event, url) => {
    if (typeof url !== "string" || !url.startsWith("https://")) {
      throw new Error("Only HTTPS links can be opened in the browser.");
    }
    await shell.openExternal(url);
    return null;
  });
  handle("dev:emit", (event, payload) => {
    event.sender.send("core:event", {
      name: payload?.name ?? "dev",
      payload: payload ?? null,
      at: Date.now(),
    });
    return { ok: true, data: null, error: "" };
  });
  handle("core:invoke", async (event, command, payload) => {
    if (!native) return { ok: false, data: null, error: "Native core is unavailable." };
    try {
      const reply = JSON.parse(await native.invoke(command, JSON.stringify(payload ?? {})));
      if (
        reply.ok &&
        /^(document:(add|import|update|remove)|video:(import|remove|saveProgress|saveSubtitles)|vocabulary:(save|edit|remove)|progress:saveDocument)$/.test(
          command,
        )
      ) {
        // Give a freshly mounted renderer time to subscribe before notifying.
        setTimeout(() => {
          try {
            event.sender.send("core:event", { name: "library-changed" });
          } catch {
            // The window may have closed before the notification fired.
          }
        }, 200);
      }
      return reply;
    } catch (error) {
      return {
        ok: false,
        data: null,
        error: error instanceof Error ? error.message : String(error),
      };
    }
  });
};
