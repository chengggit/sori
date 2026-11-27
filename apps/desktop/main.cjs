const { app, BrowserWindow, ipcMain, session } = require('electron');
const { join } = require('node:path');
const { pathToFileURL } = require('node:url');

// Avoid a userData directory derived from the scoped workspace name.
app.setName('Sori');

const isDev = !app.isPackaged;
const smoke = process.argv.includes('--smoke');
const devUrl = 'http://127.0.0.1:5173/';
const indexFile = join(__dirname, 'dist', 'index.html');
const pageUrl = isDev ? devUrl : pathToFileURL(indexFile).href;

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
        clearTimeout(watchdog);
        finishSmoke(title === 'Sori' && mounted ? 0 : 1);
      } catch (error) {
        clearTimeout(watchdog);
        finishSmoke(1, `Smoke check could not inspect the page: ${error.message}`);
      }
    });
  }

  if (isDev) {
    window.loadURL(devUrl);
  } else {
    window.loadFile(indexFile);
  }
  return window;
}

app.whenReady().then(() => {
  applyCsp();
  handle('app:ping', () => ({ ok: true, data: 'pong', error: '' }));
  createWindow();
});

app.on('window-all-closed', () => app.quit());
