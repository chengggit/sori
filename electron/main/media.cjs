const { app } = require("electron");
const { randomUUID } = require("node:crypto");
const { createReadStream } = require("node:fs");
const { realpath, stat, readFile } = require("node:fs/promises");
const { extname, join } = require("node:path");
const { Readable } = require("node:stream");

const videoExtensions = ["mkv", "mp4", "m4v", "mov", "webm", "avi", "ts"];
const videoMime = {
  mkv: "video/x-matroska",
  mp4: "video/mp4",
  m4v: "video/mp4",
  mov: "video/quicktime",
  webm: "video/webm",
  avi: "video/x-msvideo",
  ts: "video/mp2t",
};
const textCodecs = new Set(["subrip", "ass", "ssa", "mov_text", "webvtt", "text"]);
const subtitleLimit = 8 * 1024 * 1024;
const mediaFiles = new Map();

async function serveThumbnail(request) {
  const match = /^sori-thumbnail:\/\/video\/([1-9]\d*)\.jpg$/.exec(request.url);
  if (!match) return new Response(null, { status: 404 });
  if (!["GET", "HEAD"].includes(request.method)) return new Response(null, { status: 405 });
  try {
    const path = join(app.getPath("userData"), "thumbnails", `${match[1]}.jpg`);
    const info = await stat(path);
    if (!info.isFile() || info.size > 8 * 1024 * 1024) return new Response(null, { status: 404 });
    return new Response(request.method === "HEAD" ? null : await readFile(path), {
      headers: { "Content-Type": "image/jpeg", "Access-Control-Allow-Origin": "*" },
    });
  } catch {
    return new Response(null, { status: 404 });
  }
}

async function servePdf(request) {
  const match = /^sori-pdf:\/\/pdf\/(\d+)\.pdf$/.exec(request.url);
  if (!match) return new Response(null, { status: 404 });
  if (!["GET", "HEAD"].includes(request.method)) return new Response(null, { status: 405 });

  const path = join(app.getPath("userData"), "pdfs", `${match[1]}.pdf`);
  let info;
  try {
    info = await stat(path);
  } catch {
    return new Response(null, { status: 404 });
  }
  if (!info.isFile()) return new Response(null, { status: 404 });

  let start = 0;
  let end = info.size - 1;
  const headers = {
    "Content-Type": "application/pdf",
    "Accept-Ranges": "bytes",
    "Access-Control-Allow-Origin": "*",
  };
  const range = request.headers.get("range");
  const unsatisfiable = () =>
    new Response(null, {
      status: 416,
      headers: { ...headers, "Content-Range": `bytes */${info.size}` },
    });
  if (range) {
    const parts = /^bytes=(\d*)-(\d*)$/.exec(range);
    if (!parts || (!parts[1] && !parts[2])) return unsatisfiable();
    if (parts[1]) {
      start = Number(parts[1]);
      if (parts[2]) end = Math.min(end, Number(parts[2]));
    } else {
      start = Math.max(0, info.size - Number(parts[2]));
    }
    if (!Number.isSafeInteger(start) || start > end) return unsatisfiable();
    headers["Content-Range"] = `bytes ${start}-${end}/${info.size}`;
  }
  headers["Content-Length"] = String(end - start + 1);
  const body =
    request.method === "HEAD" ? null : Readable.toWeb(createReadStream(path, { start, end }));
  return new Response(body, { status: range ? 206 : 200, headers });
}

function serveMedia(request) {
  const match = /^sori-media:\/\/watch\/([^/]+)\/video(?:\.(\w+))?$/.exec(request.url);
  const selected = match ? mediaFiles.get(match[1]) : undefined;
  if (!selected || request.url !== selected.url) return new Response(null, { status: 404 });
  if (!["GET", "HEAD"].includes(request.method)) return new Response(null, { status: 405 });

  let start = 0;
  let end = selected.size - 1;
  const headers = { "Accept-Ranges": "bytes", "Content-Type": selected.type };
  const range = request.headers.get("range");
  const unsatisfiable = () =>
    new Response(null, {
      status: 416,
      headers: { ...headers, "Content-Range": `bytes */${selected.size}` },
    });
  if (range) {
    const parts = /^bytes=(\d*)-(\d*)$/.exec(range);
    if (!parts || (!parts[1] && !parts[2])) return unsatisfiable();
    if (parts[1]) {
      start = Number(parts[1]);
      if (parts[2]) end = Math.min(end, Number(parts[2]));
    } else {
      start = Math.max(0, selected.size - Number(parts[2]));
    }
    if (!Number.isSafeInteger(start) || start > end) return unsatisfiable();
    headers["Content-Range"] = `bytes ${start}-${end}/${selected.size}`;
  }
  headers["Content-Length"] = String(end - start + 1);
  const body =
    request.method === "HEAD" ? null : Readable.toWeb(createReadStream(selected.local, { start, end }));
  return new Response(body, { status: range ? 206 : 200, headers });
}

async function exposeVideo(path) {
  const local = await realpath(path);
  const info = await stat(local);
  if (!info.isFile() || !info.size) throw new Error("Choose a non-empty local video file.");
  const extension = extname(path).slice(1).toLowerCase();
  if (!videoExtensions.includes(extension)) throw new Error("Choose a supported video file.");
  const id = randomUUID();
  const url = `sori-media://watch/${id}/video${extension ? `.${extension}` : ""}`;
  const record = {
    id,
    local,
    size: info.size,
    url,
    type: videoMime[extension] || "application/octet-stream",
  };
  mediaFiles.set(id, record);
  return record;
}

function currentMedia(id) {
  const record = mediaFiles.get(id);
  if (!record) throw new Error("The open video is no longer available.");
  return record;
}

module.exports = {
  serveThumbnail,
  servePdf,
  serveMedia,
  exposeVideo,
  currentMedia,
  videoExtensions,
  textCodecs,
  subtitleLimit,
};
