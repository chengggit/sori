const { app, BrowserWindow, dialog, ipcMain, session } = require('electron');
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
let smokeDone = false;
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
      if (smokeDone) return;
      smokeDone = true;
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
        if (smokeHash === 'reader') {
          const id = await window.webContents.executeJavaScript(`(async () => {
            await window.sori.invoke('core:invoke', 'document:add', { title: '리더 스모크', content: '학교에 갔어요. '.repeat(60) });
            const state = await window.sori.invoke('core:invoke', 'library:state', {});
            return state.data.documents[0].id;
          })()`);
          await window.webContents.executeJavaScript(`location.hash = '#/reader?id=${id}'`);
          for (let attempt = 0; attempt < 10; attempt += 1) {
            await new Promise((resolve) => setTimeout(resolve, 300));
            const ready = await window.webContents.executeJavaScript(
              'Boolean(document.querySelector("[data-testid^=token-]"))',
            );
            if (ready) break;
          }
          await window.webContents.executeJavaScript(
            'document.querySelector("[data-testid^=token-]")?.click()',
          );
          await new Promise((resolve) => setTimeout(resolve, 500));
          const panel = await window.webContents.executeJavaScript(
            'document.querySelector("[data-testid=reader-analysis]")?.textContent ?? ""',
          );
          await window.webContents.executeJavaScript(`(() => {
            const save = [...document.querySelectorAll('[data-testid=analysis-panel] button')]
              .find((node) => node.textContent.includes('Save word'));
            save?.click();
          })()`);
          await new Promise((resolve) => setTimeout(resolve, 500));
          const vocabulary = await window.webContents.executeJavaScript(`(async () => {
            const state = await window.sori.invoke('core:invoke', 'library:state', {});
            return state.data.vocabulary.length;
          })()`);
          await window.webContents.executeJavaScript(`(() => {
            const element = document.querySelector('[data-testid=reader-text]');
            element.scrollTop = (element.scrollHeight - element.clientHeight) * 0.6;
            element.dispatchEvent(new Event('scroll'));
          })()`);
          await new Promise((resolve) => setTimeout(resolve, 900));
          const position = await window.webContents.executeJavaScript(`(async () => {
            const result = await window.sori.invoke('core:invoke', 'document:read', { id: ${id} });
            return result.data.position;
          })()`);
          clearTimeout(watchdog);
          finishSmoke(panel.includes('학교') && vocabulary >= 1 && position > 0.4 ? 0 : 1,
            `Reader page: ${JSON.stringify({ panel, vocabulary, position })}`);
          return;
        }
        if (smokeHash === 'library') {
          await window.webContents.executeJavaScript(
            `window.sori.invoke('core:invoke', 'document:add', { title: '스모크 문서', content: '안녕하세요' })`,
          );
          await window.webContents.executeJavaScript(`location.hash = '#/library'`);
          let listed = '';
          for (let attempt = 0; attempt < 10; attempt += 1) {
            await new Promise((resolve) => setTimeout(resolve, 300));
            listed = await window.webContents.executeJavaScript(
              'document.querySelector("[data-testid=document-list]")?.textContent ?? ""',
            );
            if (listed.includes('스모크 문서')) break;
          }
          clearTimeout(watchdog);
          finishSmoke(listed.includes('스모크 문서') ? 0 : 1, `Library page: ${listed}`);
          return;
        }
        if (smokeHash === 'analysis') {
          await new Promise((resolve) => setTimeout(resolve, 3000));
          const result = await window.webContents.executeJavaScript(`(() => {
            const panel = document.querySelector('[data-testid=analysis-panel]');
            const error = document.querySelector('[data-testid=analysis-error]');
            return { panel: Boolean(panel), terms: panel ? panel.textContent : '', error: error ? error.textContent : '' };
          })()`);
          clearTimeout(watchdog);
          finishSmoke(result.panel && !result.error && result.terms.includes('학교') ? 0 : 1,
            `Analysis page: ${JSON.stringify(result)}`);
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
    const smokeRoute =
      smokeHash && smokeHash !== 'library' && smokeHash !== 'reader' ? `#${smokeHash}` : '';
    window.loadURL(smoke ? `${devUrl}${smokeRoute}` : devUrl);
  } else {
    window.loadFile(indexFile, smoke && smokeHash ? { hash: smokeHash } : {});
  }
  return window;
}

app.whenReady().then(() => {
  applyCsp();
  handle('app:ping', () => ({ ok: true, data: 'pong', error: '' }));
  handle('dialog:openDocument', async (event) => {
    const result = await dialog.showOpenDialog(BrowserWindow.fromWebContents(event.sender), {
      title: 'Import a text or PDF file',
      properties: ['openFile'],
      filters: [
        { name: 'Text and PDF files', extensions: ['txt', 'pdf'] },
        { name: 'Text files', extensions: ['txt'] },
        { name: 'PDF files', extensions: ['pdf'] },
        { name: 'All files', extensions: ['*'] },
      ],
    });
    if (result.canceled) return null;
    const path = result.filePaths[0];
    const extension = path.split('.').pop()?.toLowerCase();
    if (extension !== 'txt' && extension !== 'pdf') {
      throw new Error('Choose a .txt or .pdf file.');
    }
    return path;
  });
  handle('dev:emit', (event, payload) => {
    event.sender.send('core:event', {
      name: payload?.name ?? 'dev',
      payload: payload ?? null,
      at: Date.now(),
    });
    return { ok: true, data: null, error: '' };
  });
  handle('core:invoke', async (_event, command, payload) => {
    if (!native) return { ok: false, data: null, error: 'Native core is unavailable.' };
    try {
      const reply = JSON.parse(await native.invoke(command, JSON.stringify(payload ?? {})));
      if (reply.ok && /^(document|video|vocabulary|progress|library):/.test(command)) {
        // Give a freshly mounted renderer time to subscribe before notifying.
        setTimeout(() => {
          try {
            event.sender.send('core:event', { name: 'library-changed' });
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
  createWindow();
});

app.on('window-all-closed', () => app.quit());
