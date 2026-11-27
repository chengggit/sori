const { ipcMain, session } = require("electron");

function applyCsp(isDev) {
  // Allow only the configured dictionary/YouTube origins and the dev HMR socket.
  const csp = isDev
    ? "default-src 'self'; script-src 'self' https://www.youtube.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: https://i.ytimg.com; font-src 'self' data:; media-src 'self' sori-media:; frame-src https://www.youtube.com https://korean.dict.naver.com https://papago.naver.com https://krdict.korean.go.kr; connect-src 'self' sori-pdf: sori-media: ws://127.0.0.1:5173"
    : "default-src 'self'; script-src 'self' https://www.youtube.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: https://i.ytimg.com; font-src 'self' data:; media-src 'self' sori-media:; frame-src https://www.youtube.com https://korean.dict.naver.com https://papago.naver.com https://krdict.korean.go.kr; connect-src sori-pdf: sori-media:";

  session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
    callback({
      responseHeaders: {
        ...details.responseHeaders,
        "Content-Security-Policy": [csp],
      },
    });
  });
}

function isOwnFrame(frame, pageUrl) {
  if (!frame || frame.parent) return false;
  const url = frame.url.split("#")[0];
  return url === pageUrl || url.startsWith(`${pageUrl}?`);
}

function handle(pageUrl, channel, listener) {
  ipcMain.handle(channel, (event, ...args) => {
    if (!isOwnFrame(event.senderFrame, pageUrl)) throw new Error("Unauthorized IPC caller.");
    return listener(event, ...args);
  });
}

module.exports = { applyCsp, handle };
