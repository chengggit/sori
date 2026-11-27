const { app, BrowserWindow, ipcMain, session } = require('electron');
const { join } = require('node:path');
const { homedir } = require('node:os');
const { pathToFileURL } = require('node:url');

// Avoid a userData directory derived from the scoped workspace name.
app.setName('Sori');

// Qt used QStandardPaths::GenericDataLocation + "/com.sori.app" for the library.
// Match it so existing users keep their data without an export/import step.
function legacyDataDirectory() {
  if (process.env.SORI_DATA_DIR) return process.env.SORI_DATA_DIR;
  if (process.platform === 'linux') {
    return join(process.env.XDG_DATA_HOME || join(homedir(), '.local', 'share'), 'com.sori.app');
  }
  return join(app.getPath('appData'), 'com.sori.app');
}
app.setPath('userData', legacyDataDirectory());

const isDev = !app.isPackaged;
const smoke = process.argv.includes('--smoke');
const smokeHash = process.env.SORI_SMOKE_HASH;
const devUrl = 'http://127.0.0.1:5173/';
const indexFile = join(__dirname, 'dist', 'index.html');
const pageUrl = isDev ? devUrl : pathToFileURL(indexFile).href;

function loadNative() {
  const addonPath = isDev
    ? join(__dirname, 'native', 'sori-node.node')
    : join(process.resourcesPath, 'app.asar.unpacked', 'native', 'sori-node.node');
  try {
    const addon = require(addonPath);
    const resources = isDev
      ? join(__dirname, '..', '..', 'resources', 'kiwi')
      : join(process.resourcesPath, 'kiwi');
    addon.init(resources);
    addon.initLibrary(app.getPath('userData'));
    return addon;
  } catch (error) {
    console.error('Native core is unavailable:', error.message);
    return null;
  }
}

const native = loadNative();

function applyCsp() {
  // Dev needs the Vite HMR socket; packaged builds allow no network origins.
  // Dictionary and YouTube allowlists will be added when those features land.
  const csp = isDev
    ? "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self' ws://127.0.0.1:5173"
    : "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'none'";

  session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
    callback({
      responseHeaders: {
        ...details.responseHeaders,
        'Content-Security-Policy': [csp],
      },
    });
  });
}

function isOwnFrame(frame) {
  if (!frame || frame.parent) return false;
  const url = frame.url.split('#')[0];
  return url === pageUrl || url.startsWith(`${pageUrl}?`);
}

function handle(channel, listener) {
  ipcMain.handle(channel, (event, ...args) => {
    if (!isOwnFrame(event.senderFrame)) throw new Error('Unauthorized IPC caller.');
    return listener(event, ...args);
  });
}

function finishSmoke(exitCode, message) {
  if (message) console.error(message);
  app.exit(exitCode);
}

function createWindow() {
  const window = new BrowserWindow({
    width: 1060,
    height: 780,
    minWidth: 640,
    minHeight: 480,
    backgroundColor: '#141414',
    webPreferences: {
      preload: join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      sandbox: true,
      nodeIntegration: false,
    },
  });
  window.removeMenu();
  window.webContents.on('will-navigate', (event) => event.preventDefault());
  window.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));

  if (smoke) {
    const watchdog = setTimeout(
      () => finishSmoke(2, 'Smoke check timed out waiting for the page.'),
      20_000,
    );
    window.webContents.once('did-fail-load', (_event, code, description) => {
      clearTimeout(watchdog);
      finishSmoke(1, `Smoke check failed to load: ${description} (${code})`);
    });
    window.webContents.once('did-finish-load', async () => {
      try {
        const title = await window.webContents.executeJavaScript('document.title');
        const mounted = await window.webContents.executeJavaScript(
          'Boolean(document.querySelector("#app > *"))',
        );
        if (title !== 'Sori' || !mounted) {
          clearTimeout(watchdog);
          finishSmoke(1);
          return;
        }
        if (smokeHash === 'bridge') {
          await new Promise((resolve) => setTimeout(resolve, 3000));
          const values = await window.webContents.executeJavaScript(
            '[...document.querySelectorAll("[data-testid^=bridge-]")].map((node) => node.textContent)',
          );
          const populated = values.length === 3 && values.every((value) => value && value !== 'waiting…');
          const analyzed = !isDev || String(values[1]).includes('NNG');
          clearTimeout(watchdog);
          finishSmoke(populated && analyzed ? 0 : 1, `Bridge page: ${JSON.stringify(values)}`);
          return;
        }
        clearTimeout(watchdog);
        finishSmoke(0);
      } catch (error) {
        clearTimeout(watchdog);
        finishSmoke(1, `Smoke check could not inspect the page: ${error.message}`);
      }
    });
  }

  if (isDev) {
    window.loadURL(smoke && smokeHash ? `${devUrl}#${smokeHash}` : devUrl);
  } else {
    window.loadFile(indexFile, smoke && smokeHash ? { hash: smokeHash } : {});
  }
  return window;
}

app.whenReady().then(() => {
  applyCsp();
  handle('app:ping', () => ({ ok: true, data: 'pong', error: '' }));
  handle('dev:emit', (event, payload) => {
    event.sender.send('core:event', { name: 'dev', payload: payload ?? null, at: Date.now() });
    return { ok: true, data: null, error: '' };
  });
  handle('core:invoke', async (_event, command, payload) => {
    if (!native) return { ok: false, data: null, error: 'Native core is unavailable.' };
    try {
      return JSON.parse(await native.invoke(command, JSON.stringify(payload ?? {})));
    } catch (error) {
      return {
        ok: false,
        data: null,
        error: error instanceof Error ? error.message : String(error),
      };
    }
  });
  createWindow();
});

app.on('window-all-closed', () => app.quit());
