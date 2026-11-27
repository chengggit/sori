const { app, BrowserWindow, dialog, ipcMain, protocol, session } = require('electron');
const { execFile, execFileSync } = require('node:child_process');
const { randomUUID } = require('node:crypto');
const { createReadStream, writeFileSync } = require('node:fs');
const { realpath, stat, readFile } = require('node:fs/promises');
const { basename, extname, join } = require('node:path');
const { homedir, tmpdir } = require('node:os');
const { Readable } = require('node:stream');
const { promisify } = require('node:util');
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

protocol.registerSchemesAsPrivileged([
  {
    scheme: 'sori-pdf',
    privileges: { standard: true, secure: true, stream: true, supportFetchAPI: true, corsEnabled: true },
  },
  {
    scheme: 'sori-media',
    privileges: { standard: true, secure: true, stream: true, supportFetchAPI: true, corsEnabled: true },
  },
]);

const isDev = !app.isPackaged;
const smoke = process.argv.includes('--smoke');
const smokeHash = process.env.SORI_SMOKE_HASH;
let smokeDone = false;
const devUrl = 'http://127.0.0.1:5173/';
const indexFile = join(__dirname, 'dist', 'index.html');
const pageUrl = isDev ? devUrl : pathToFileURL(indexFile).href;

const run = promisify(execFile);
const videoExtensions = ['mkv', 'mp4', 'm4v', 'mov', 'webm', 'avi', 'ts'];
const videoMime = {
  mkv: 'video/x-matroska',
  mp4: 'video/mp4',
  m4v: 'video/mp4',
  mov: 'video/quicktime',
  webm: 'video/webm',
  avi: 'video/x-msvideo',
  ts: 'video/mp2t',
};
const textCodecs = new Set(['subrip', 'ass', 'ssa', 'mov_text', 'webvtt', 'text']);
const subtitleLimit = 8 * 1024 * 1024;
const mediaFiles = new Map();

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

async function servePdf(request) {
  const match = /^sori-pdf:\/\/pdf\/(\d+)\.pdf$/.exec(request.url);
  if (!match) return new Response(null, { status: 404 });
  if (!['GET', 'HEAD'].includes(request.method)) return new Response(null, { status: 405 });

  const path = join(app.getPath('userData'), 'pdfs', `${match[1]}.pdf`);
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
    'Content-Type': 'application/pdf',
    'Accept-Ranges': 'bytes',
    'Access-Control-Allow-Origin': '*',
  };
  const range = request.headers.get('range');
  const unsatisfiable = () =>
    new Response(null, {
      status: 416,
      headers: { ...headers, 'Content-Range': `bytes */${info.size}` },
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
    headers['Content-Range'] = `bytes ${start}-${end}/${info.size}`;
  }
  headers['Content-Length'] = String(end - start + 1);
  const body =
    request.method === 'HEAD' ? null : Readable.toWeb(createReadStream(path, { start, end }));
  return new Response(body, { status: range ? 206 : 200, headers });
}

function serveMedia(request) {
  const match = /^sori-media:\/\/watch\/([^/]+)\/video(?:\.(\w+))?$/.exec(request.url);
  const selected = match ? mediaFiles.get(match[1]) : undefined;
  if (!selected || request.url !== selected.url) return new Response(null, { status: 404 });
  if (!['GET', 'HEAD'].includes(request.method)) return new Response(null, { status: 405 });

  let start = 0;
  let end = selected.size - 1;
  const headers = { 'Accept-Ranges': 'bytes', 'Content-Type': selected.type };
  const range = request.headers.get('range');
  const unsatisfiable = () =>
    new Response(null, {
      status: 416,
      headers: { ...headers, 'Content-Range': `bytes */${selected.size}` },
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
    headers['Content-Range'] = `bytes ${start}-${end}/${selected.size}`;
  }
  headers['Content-Length'] = String(end - start + 1);
  const body =
    request.method === 'HEAD' ? null : Readable.toWeb(createReadStream(selected.local, { start, end }));
  return new Response(body, { status: range ? 206 : 200, headers });
}

async function exposeVideo(path) {
  const local = await realpath(path);
  const info = await stat(local);
  if (!info.isFile() || !info.size) throw new Error('Choose a non-empty local video file.');
  const extension = extname(path).slice(1).toLowerCase();
  if (!videoExtensions.includes(extension)) throw new Error('Choose a supported video file.');
  const id = randomUUID();
  const url = `sori-media://watch/${id}/video${extension ? `.${extension}` : ''}`;
  const record = { id, local, size: info.size, url, type: videoMime[extension] || 'application/octet-stream' };
  mediaFiles.set(id, record);
  return record;
}

function currentMedia(id) {
  const record = mediaFiles.get(id);
  if (!record) throw new Error('The open video is no longer available.');
  return record;
}

function applyCsp() {
  // Dev needs the Vite HMR socket; packaged builds allow no network origins.
  // Dictionary and YouTube allowlists will be added when those features land.
  const csp = isDev
    ? "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; media-src 'self' sori-media:; connect-src 'self' sori-pdf: sori-media: ws://127.0.0.1:5173"
    : "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; media-src 'self' sori-media:; connect-src sori-pdf: sori-media:";

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
        if (smokeHash === 'subtitles') {
          const directory = process.env.SORI_DATA_DIR || tmpdir();
          const srtPath = join(directory, 'sori-subs.srt');
          const videoPath = join(directory, 'sori-subs.mkv');
          writeFileSync(
            srtPath,
            '1\n00:00:00,000 --> 00:00:03,000\n안녕하세요\n\n' +
              '2\n00:00:03,000 --> 00:00:06,000\n학교에 갔어요\n',
          );
          execFileSync(
            'ffmpeg',
            [
              '-v',
              'error',
              '-f',
              'lavfi',
              '-i',
              'color=c=blue:s=320x240:d=6',
              '-i',
              srtPath,
              '-map',
              '0:v',
              '-map',
              '1:s',
              '-c:s',
              'srt',
              '-pix_fmt',
              'yuv420p',
              '-metadata:s:s:0',
              'language=kor',
              '-metadata:s:s:0',
              'title=Korean',
              '-y',
              videoPath,
            ],
            { timeout: 30000 },
          );
          const id = await window.webContents.executeJavaScript(`(async () => {
            const imported = await window.sori.invoke('core:invoke', 'video:import', { path: ${JSON.stringify(videoPath)} });
            if (!imported.ok) return -1;
            const state = await window.sori.invoke('core:invoke', 'library:state', {});
            return state.data.videos[0].id;
          })()`);
          await window.webContents.executeJavaScript(`location.hash = '#/watch?id=${id}'`);
          let caption = '';
          for (let attempt = 0; attempt < 30; attempt += 1) {
            await new Promise((resolve) => setTimeout(resolve, 300));
            caption = await window.webContents.executeJavaScript(
              'document.querySelector("[data-testid=primary-caption]")?.textContent ?? ""',
            );
            if (caption.includes('안녕하세요')) break;
          }
          await window.webContents.executeJavaScript(`(() => {
            document.querySelector('[data-testid=primary-caption] button')?.click();
          })()`);
          await new Promise((resolve) => setTimeout(resolve, 600));
          const analysis = await window.webContents.executeJavaScript(
            'document.querySelector("[data-testid=watch-analysis]")?.textContent ?? ""',
          );
          await window.webContents.executeJavaScript(`(() => {
            document.querySelector('[data-testid=cue-3]')?.click();
          })()`);
          await new Promise((resolve) => setTimeout(resolve, 300));
          const position = await window.webContents.executeJavaScript(
            'document.querySelector("video").currentTime',
          );
          const transcript = await window.webContents.executeJavaScript(
            'Boolean(document.querySelector("[data-testid=transcript]"))',
          );
          clearTimeout(watchdog);
          finishSmoke(
            caption.includes('안녕하세요') && analysis.includes('Ending') && position >= 3 && transcript
              ? 0
              : 1,
            `Subtitles: ${JSON.stringify({ caption, analysis, position, transcript })}`,
          );
          return;
        }
        if (smokeHash === 'watch') {
          const videoPath = join(process.env.SORI_DATA_DIR || tmpdir(), 'sori-smoke.mkv');
          execFileSync(
            'ffmpeg',
            [
              '-v',
              'error',
              '-f',
              'lavfi',
              '-i',
              'color=c=blue:s=320x240:d=4',
              '-pix_fmt',
              'yuv420p',
              '-y',
              videoPath,
            ],
            { timeout: 30000 },
          );
          const id = await window.webContents.executeJavaScript(`(async () => {
            const imported = await window.sori.invoke('core:invoke', 'video:import', { path: ${JSON.stringify(videoPath)} });
            if (!imported.ok) return -1;
            const state = await window.sori.invoke('core:invoke', 'library:state', {});
            return state.data.videos[0].id;
          })()`);
          await window.webContents.executeJavaScript(`location.hash = '#/watch?id=${id}'`);
          let ready = false;
          for (let attempt = 0; attempt < 20; attempt += 1) {
            await new Promise((resolve) => setTimeout(resolve, 300));
            ready = await window.webContents.executeJavaScript(`(() => {
              const element = document.querySelector('video');
              return Boolean(element && element.src.startsWith('sori-media:') && element.readyState >= 1);
            })()`);
            if (ready) break;
          }
          await window.webContents.executeJavaScript(
            'document.querySelector("[aria-label=Play]")?.click()',
          );
          await new Promise((resolve) => setTimeout(resolve, 1200));
          const currentTime = await window.webContents.executeJavaScript(
            'document.querySelector("video").currentTime',
          );
          await window.webContents.executeJavaScript(`(() => {
            const element = document.querySelector('video');
            element.pause();
            element.currentTime = 2;
          })()`);
          await new Promise((resolve) => setTimeout(resolve, 600));
          const saved = await window.webContents.executeJavaScript(`(async () => {
            const result = await window.sori.invoke('core:invoke', 'video:read', { id: ${id} });
            return result.data.seconds;
          })()`);
          clearTimeout(watchdog);
          finishSmoke(ready && currentTime > 0 && saved > 0 ? 0 : 1,
            `Watch page: ${JSON.stringify({ id, ready, currentTime, saved })}`);
          return;
        }
        if (smokeHash === 'pdf') {
          const fixture = join(process.cwd(), 'tests', 'fixtures', 'pdf-rendering.pdf');
          const id = await window.webContents.executeJavaScript(`(async () => {
            const imported = await window.sori.invoke('core:invoke', 'document:import', { path: ${JSON.stringify(fixture)} });
            if (!imported.ok) return -1;
            const state = await window.sori.invoke('core:invoke', 'library:state', {});
            return state.data.documents[0].id;
          })()`);
          await window.webContents.executeJavaScript(`location.hash = '#/reader?id=${id}'`);
          let pages = 0;
          for (let attempt = 0; attempt < 20; attempt += 1) {
            await new Promise((resolve) => setTimeout(resolve, 300));
            pages = await window.webContents.executeJavaScript(
              'document.querySelectorAll("[data-testid=pdf-container] canvas").length',
            );
            if (pages > 0) break;
          }
          const problem = await window.webContents.executeJavaScript(
            'document.querySelector("[data-testid=pdf-error]")?.textContent ?? ""',
          );
          const spans = await window.webContents.executeJavaScript(
            'document.querySelectorAll("[data-testid=pdf-container] .textLayer span").length',
          );
          let analysis = '';
          if (spans > 0) {
            await window.webContents.executeJavaScript(
              'document.querySelector("[data-testid=pdf-container] .textLayer span").click()',
            );
            for (let attempt = 0; attempt < 10; attempt += 1) {
              await new Promise((resolve) => setTimeout(resolve, 300));
              analysis = await window.webContents.executeJavaScript(
                'document.querySelector("[data-testid=reader-analysis]")?.textContent ?? ""',
              );
              if (analysis) break;
            }
          }
          await window.webContents.executeJavaScript(`(() => {
            const scroll = [...document.querySelectorAll('button')]
              .find((node) => node.textContent.trim() === 'Scroll');
            scroll?.click();
          })()`);
          await new Promise((resolve) => setTimeout(resolve, 1200));
          const scrollPages = await window.webContents.executeJavaScript(
            'document.querySelectorAll("[data-testid=pdf-container] canvas").length',
          );
          clearTimeout(watchdog);
          finishSmoke(id > 0 && pages > 0 && scrollPages > 0 && !problem && analysis ? 0 : 1,
            `PDF page: ${JSON.stringify({ id, pages, spans, analysis, scrollPages, problem })}`);
          return;
        }
        if (smokeHash === 'vocabulary') {
          await window.webContents.executeJavaScript(`(async () => {
            await window.sori.invoke('core:invoke', 'document:add', { title: '단어 스모크', content: '안녕하세요' });
            const state = await window.sori.invoke('core:invoke', 'library:state', {});
            const documentId = state.data.documents[0].id;
            await window.sori.invoke('core:invoke', 'vocabulary:save', {
              kind: 'document', id: documentId,
              input: { word: '안녕', context: '안녕하세요', tags: [] }
            });
          })()`);
          await window.webContents.executeJavaScript(`location.hash = '#/vocabulary'`);
          for (let attempt = 0; attempt < 10; attempt += 1) {
            await new Promise((resolve) => setTimeout(resolve, 300));
            const ready = await window.webContents.executeJavaScript(
              'Boolean(document.querySelector("[data-testid^=vocabulary-]"))',
            );
            if (ready) break;
          }
          await window.webContents.executeJavaScript(`(() => {
            document.querySelector('[aria-label="Edit 안녕"]').click();
          })()`);
          await new Promise((resolve) => setTimeout(resolve, 300));
          await window.webContents.executeJavaScript(`(() => {
            const field = document.querySelector('[data-testid=vocabulary-editor] textarea[aria-label=Meaning]');
            const setter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set;
            setter.call(field, 'hello');
            field.dispatchEvent(new Event('input', { bubbles: true }));
          })()`);
          await window.webContents.executeJavaScript(
            'document.querySelector("[data-testid=save-vocabulary]").click()',
          );
          await new Promise((resolve) => setTimeout(resolve, 600));
          const meaning = await window.webContents.executeJavaScript(`(async () => {
            const state = await window.sori.invoke('core:invoke', 'library:state', {});
            return state.data.vocabulary[0]?.definition?.text ?? '';
          })()`);
          await window.webContents.executeJavaScript(`(() => {
            document.querySelector('[aria-label="Remove 안녕"]').click();
          })()`);
          await new Promise((resolve) => setTimeout(resolve, 600));
          const dialogVisible = await window.webContents.executeJavaScript(
            'Boolean(document.querySelector("[data-testid=vocabulary-delete]"))',
          );
          await window.webContents.executeJavaScript(`(() => {
            const remove = [...document.querySelectorAll('[data-testid=vocabulary-delete] button')]
              .find((node) => node.textContent.includes('Remove'));
            remove?.click();
          })()`);
          let remaining = 1;
          for (let attempt = 0; attempt < 20; attempt += 1) {
            await new Promise((resolve) => setTimeout(resolve, 300));
            remaining = await window.webContents.executeJavaScript(`(async () => {
              const state = await window.sori.invoke('core:invoke', 'library:state', {});
              return state.data.vocabulary.length;
            })()`);
            if (remaining === 0) break;
          }
          clearTimeout(watchdog);
          finishSmoke(meaning === 'hello' && remaining === 0 ? 0 : 1,
            `Vocabulary page: ${JSON.stringify({ meaning, dialogVisible, remaining })}`);
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
      smokeHash &&
      smokeHash !== 'library' &&
      smokeHash !== 'reader' &&
      smokeHash !== 'vocabulary' &&
      smokeHash !== 'pdf' &&
      smokeHash !== 'watch' &&
      smokeHash !== 'subtitles'
        ? `#${smokeHash}`
        : '';
    window.loadURL(smoke ? `${devUrl}${smokeRoute}` : devUrl);
  } else {
    window.loadFile(indexFile, smoke && smokeHash ? { hash: smokeHash } : {});
  }
  return window;
}

app.whenReady().then(() => {
  protocol.handle('sori-pdf', servePdf);
  protocol.handle('sori-media', serveMedia);
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
  handle('dialog:openVideo', async (event) => {
    const result = await dialog.showOpenDialog(BrowserWindow.fromWebContents(event.sender), {
      title: 'Import a video',
      properties: ['openFile'],
      filters: [
        { name: 'Video files', extensions: videoExtensions },
        { name: 'All files', extensions: ['*'] },
      ],
    });
    return result.canceled ? null : result.filePaths[0];
  });
  handle('video:expose', async (_event, path) => {
    const record = await exposeVideo(path);
    return { id: record.id, url: record.url, name: basename(record.local) };
  });
  handle('video:probe', async (_event, id) => {
    const selected = currentMedia(id);
    try {
      const { stdout } = await run(
        'ffprobe',
        [
          '-v',
          'error',
          '-protocol_whitelist',
          'file',
          '-format_whitelist',
          'mov,matroska,webm,avi,mpegts',
          '-show_entries',
          'format=format_name:stream=index,codec_type,codec_name:stream_tags=language,title',
          '-of',
          'json',
          '-i',
          selected.local,
        ],
        { maxBuffer: 1024 * 1024, timeout: 30000 },
      );
      const { format, streams = [] } = JSON.parse(stdout);
      return {
        container: format?.format_name ?? '',
        video: streams.find((stream) => stream.codec_type === 'video')?.codec_name ?? '',
        audio: streams
          .filter((stream) => stream.codec_type === 'audio')
          .map((stream) => stream.codec_name),
        tracks: streams
          .filter((stream) => stream.codec_type === 'subtitle' && textCodecs.has(stream.codec_name))
          .map((stream) => ({
            index: stream.index,
            language: stream.tags?.language ?? '',
            label: [stream.tags?.title, stream.tags?.language, stream.codec_name]
              .filter(Boolean)
              .join(' · '),
          })),
      };
    } catch (error) {
      return {
        error:
          error.code === 'ENOENT'
            ? 'Install FFprobe to inspect embedded tracks.'
            : 'FFprobe could not read this file’s track information.',
      };
    }
  });
  handle('video:track', async (_event, id, index) => {
    const selected = currentMedia(id);
    const probe = await run('ffprobe', [
      '-v',
      'error',
      '-protocol_whitelist',
      'file',
      '-show_entries',
      'stream=index,codec_type,codec_name',
      '-of',
      'json',
      '-i',
      selected.local,
    ], { maxBuffer: 1024 * 1024, timeout: 30000 })
      .then(({ stdout }) => JSON.parse(stdout))
      .catch(() => ({ streams: [] }));
    const track = (probe.streams ?? []).find(
      (stream) => stream.index === index && stream.codec_type === 'subtitle',
    );
    if (!track) throw new Error('Choose a text subtitle track.');
    try {
      const { stdout } = await run(
        'ffmpeg',
        [
          '-v',
          'error',
          '-nostdin',
          '-protocol_whitelist',
          'file',
          '-format_whitelist',
          'mov,matroska,webm,avi,mpegts',
          '-i',
          selected.local,
          '-map',
          `0:${index}`,
          '-c:s',
          'webvtt',
          '-f',
          'webvtt',
          'pipe:1',
        ],
        { maxBuffer: subtitleLimit, timeout: 45000 },
      );
      return stdout;
    } catch (error) {
      throw new Error(
        error.code === 'ENOENT'
          ? 'Install FFmpeg to extract embedded subtitles.'
          : 'FFmpeg could not extract this text track.',
      );
    }
  });
  handle('video:attach', async (event, id) => {
    currentMedia(id);
    const result = await dialog.showOpenDialog(BrowserWindow.fromWebContents(event.sender), {
      properties: ['openFile'],
      filters: [{ name: 'Text subtitles', extensions: ['srt', 'vtt'] }],
    });
    if (result.canceled) return null;
    currentMedia(id);
    const path = result.filePaths[0];
    const info = await stat(path);
    if (!info.isFile() || info.size > subtitleLimit) {
      throw new Error('Choose a subtitle file under 8 MiB.');
    }
    return {
      name: basename(path),
      text: new TextDecoder('utf-8', { fatal: true }).decode(await readFile(path)),
    };
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
