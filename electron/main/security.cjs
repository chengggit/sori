const { ipcMain, session } = require("electron");

function applyCsp(isDev) {
  // Custom dictionary templates need HTTPS frames; scripts, connections and
  // all other resource types keep their explicit application allowlists.
  const csp = isDev
    ? "default-src 'self'; script-src 'self' https://www.youtube.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: sori-thumbnail: https://i.ytimg.com; font-src 'self' data:; media-src 'self' sori-media:; frame-src https:; connect-src 'self' sori-pdf: sori-media: ws://127.0.0.1:5173"
    : "default-src 'self'; script-src 'self' https://www.youtube.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: sori-thumbnail: https://i.ytimg.com; font-src 'self' data:; media-src 'self' sori-media:; frame-src https:; connect-src sori-pdf: sori-media:";

  session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
    // Never overwrite a third-party dictionary's own script/frame policy.
    if (details.resourceType !== "mainFrame") {
      callback({ responseHeaders: details.responseHeaders });
      return;
    }
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
