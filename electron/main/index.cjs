const { app, BrowserWindow, protocol } = require("electron");
const { join } = require("node:path");
const { pathToFileURL } = require("node:url");
const { legacyDataDirectory, loadNative } = require("./runtime.cjs");
const { servePdf, serveMedia } = require("./media.cjs");
const { applyCsp, handle } = require("./security.cjs");
const registerIpc = require("./ipc.cjs");

app.setPath("userData", legacyDataDirectory());
protocol.registerSchemesAsPrivileged([
  {
    scheme: "sori-pdf",
    privileges: {
      standard: true,
      secure: true,
      stream: true,
      supportFetchAPI: true,
      corsEnabled: true,
    },
  },
  {
    scheme: "sori-media",
    privileges: {
      standard: true,
      secure: true,
      stream: true,
      supportFetchAPI: true,
      corsEnabled: true,
    },
  },
]);

const isDev = !app.isPackaged;
const smoke = process.argv.includes("--smoke");
const smokeHash = process.env.SORI_SMOKE_HASH;
const devUrl = "http://127.0.0.1:5173/";
const indexFile = join(app.getAppPath(), "dist", "index.html");
const pageUrl = isDev ? devUrl : pathToFileURL(indexFile).href;
const native = loadNative();

function createWindow() {
  const window = new BrowserWindow({
    width: 1060,
    height: 780,
    minWidth: 640,
    minHeight: 480,
    backgroundColor: "#141414",
    webPreferences: {
      preload: join(app.getAppPath(), "electron", "preload", "index.cjs"),
      contextIsolation: true,
      sandbox: true,
      nodeIntegration: false,
    },
  });
  window.removeMenu();
  window.webContents.on("will-navigate", (event) => event.preventDefault());
  window.webContents.setWindowOpenHandler(() => ({ action: "deny" }));

  if (smoke) {
    require("../../tests/smoke/desktop.cjs")(window, { app, isDev, smokeHash });
  }

  // Feature checks seed data before navigating. Only diagnostics can mount directly.
  const smokeRoute = smoke && ["bridge", "analysis"].includes(smokeHash) ? smokeHash : "";
  if (isDev) {
    window.loadURL(smokeRoute ? `${devUrl}#${smokeRoute}` : devUrl);
  } else {
    window.loadFile(indexFile, smokeRoute ? { hash: smokeRoute } : {});
  }
  return window;
}

app.whenReady().then(() => {
  protocol.handle("sori-pdf", servePdf);
  protocol.handle("sori-media", serveMedia);
  applyCsp(isDev);
  registerIpc((channel, listener) => handle(pageUrl, channel, listener), native);
  createWindow();
});

app.on("window-all-closed", () => app.quit());
