const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");
const { test } = require("node:test");
const { runInNewContext } = require("node:vm");

function loadMainModule(name, mocks, globals = {}) {
  const module = { exports: {} };
  runInNewContext(readFileSync(join(__dirname, "../../electron/main", name), "utf8"), {
    module,
    require: (id) => (Object.hasOwn(mocks, id) ? mocks[id] : require(id)),
    ...globals,
  });
  return module.exports;
}

test("successful mutations notify the invoking renderer; failures do not", async () => {
  const handlers = new Map();
  const timers = [];
  const sent = [];
  const registerIpc = loadMainModule(
    "ipc.cjs",
    { electron: {}, "./runtime.cjs": {}, "./media.cjs": {} },
    { setTimeout: (callback) => timers.push(callback) },
  );
  let reply = { ok: true, data: null, error: "" };
  registerIpc((channel, handler) => handlers.set(channel, handler), {
    invoke: async () => JSON.stringify(reply),
  });
  const invoke = handlers.get("core:invoke");
  const event = { sender: { send: (...args) => sent.push(args) } };
  assert.equal((await invoke(event, "document:add", {})).ok, true);
  assert.equal(timers.length, 1);
  timers.shift()();
  assert.equal(sent[0][0], "core:event");
  assert.equal(sent[0][1].name, "library-changed");

  for (const command of ["library:state", "document:read", "video:read", "vocabulary:find"]) {
    await invoke(event, command, {});
  }
  assert.equal(timers.length, 0);

  reply = { ok: false, data: null, error: "Import failed" };
  assert.equal((await invoke(event, "document:add", {})).error, "Import failed");
  await invoke(event, "analyzeText", {});
  assert.equal(timers.length, 0);
  assert.equal(sent.length, 1);
});

test("IPC accepts only the app top-level frame in development and packages", async () => {
  const handlers = new Map();
  const { handle } = loadMainModule("security.cjs", {
    electron: { ipcMain: { handle: (channel, handler) => handlers.set(channel, handler) } },
  });
  for (const pageUrl of ["http://127.0.0.1:5173/", "file:///app/dist/index.html"]) {
    handle(pageUrl, "test", (_event, payload) => payload);
    const invoke = handlers.get("test");
    for (const suffix of ["", "#/library", "?test=1#/library"]) {
      assert.equal(invoke({ senderFrame: { url: pageUrl + suffix } }, "ok"), "ok");
    }
    for (const senderFrame of [
      null,
      { url: "https://example.com" },
      { url: pageUrl + "evil" },
      { url: pageUrl, parent: {} },
    ]) {
      assert.throws(() => invoke({ senderFrame }), /Unauthorized IPC caller/);
    }
  }
});

test("native resource paths resolve from the application root in dev and packages", () => {
  for (const isPackaged of [false, true]) {
    const initialized = [];
    const addon = {
      init: (path) => initialized.push(path),
      initLibrary: (path) => initialized.push(path),
    };
    const addonPath = isPackaged
      ? "/bundle/app.asar.unpacked/native/sori-node.node"
      : "/repo/native/sori-node.node";
    const { loadNative, toolPath } = loadMainModule(
      "runtime.cjs",
      {
        electron: {
          app: {
            isPackaged,
            setName: () => {},
            getAppPath: () => "/repo",
            getPath: () => "/temp/library",
          },
        },
        "node:path": require("node:path").posix,
        [addonPath]: addon,
      },
      { process: { platform: "linux", resourcesPath: "/bundle", env: {} }, console },
    );
    assert.equal(loadNative(), addon);
    assert.equal(initialized[0], isPackaged ? "/bundle/kiwi" : "/repo/resources/kiwi");
    assert.equal(initialized[1], "/temp/library");
    assert.equal(toolPath("ffmpeg"), isPackaged ? "/bundle/bin/ffmpeg" : "ffmpeg");
  }
});

test("thumbnail protocol only serves managed numeric JPEG paths", async (t) => {
  const { mkdtempSync, mkdirSync, writeFileSync, rmSync } = require("node:fs");
  const { tmpdir } = require("node:os");
  const directory = mkdtempSync(join(tmpdir(), "sori-thumbnails-"));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  mkdirSync(join(directory, "thumbnails"));
  writeFileSync(join(directory, "thumbnails/1.jpg"), Buffer.from([255, 216, 255, 217]));
  const { serveThumbnail } = loadMainModule(
    "media.cjs",
    { electron: { app: { getPath: () => directory } } },
    { Response },
  );
  const good = await serveThumbnail({ url: "sori-thumbnail://video/1.jpg", method: "GET" });
  assert.equal(good.status, 200);
  assert.equal(good.headers.get("content-type"), "image/jpeg");
  assert.equal((await good.arrayBuffer()).byteLength, 4);
  assert.equal(
    (await serveThumbnail({ url: "sori-thumbnail://video/1.jpg", method: "HEAD" })).body,
    null,
  );
  for (const url of [
    "sori-thumbnail://video/../1.jpg",
    "sori-thumbnail://video/0.jpg",
    "sori-thumbnail://other/1.jpg",
    "sori-thumbnail://video/2.jpg",
  ]) {
    assert.equal((await serveThumbnail({ url, method: "GET" })).status, 404);
  }
  assert.equal(
    (await serveThumbnail({ url: "sori-thumbnail://video/1.jpg", method: "POST" })).status,
    405,
  );
});

test("CSP allows HTTPS dictionary frames without overwriting their response policy", () => {
  let onHeaders;
  const { applyCsp } = loadMainModule("security.cjs", {
    electron: {
      session: {
        defaultSession: {
          webRequest: {
            onHeadersReceived: (handler) => {
              onHeaders = handler;
            },
          },
        },
      },
    },
  });
  applyCsp(false);
  let result;
  const original = {
    "Content-Security-Policy": ["script-src https://dictionary.example"],
    "X-Frame-Options": ["SAMEORIGIN"],
  };
  onHeaders({ resourceType: "subFrame", responseHeaders: original }, (value) => {
    result = value;
  });
  assert.equal(result.responseHeaders, original);
  onHeaders({ resourceType: "mainFrame", responseHeaders: {} }, (value) => {
    result = value;
  });
  const policy = result.responseHeaders["Content-Security-Policy"][0];
  assert.match(policy, /frame-src https:;/);
  assert.match(policy, /default-src 'self'/);
  assert.match(policy, /script-src 'self' https:\/\/www.youtube.com;/);
});
