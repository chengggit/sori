const { contextBridge, ipcRenderer } = require('electron');

// Only these channels may cross the preload boundary. Keep in sync with
// DesktopBridge in src/bridge.ts until the bridge is generated from one source.
const commands = Object.freeze(['app:ping', 'core:invoke', 'dev:emit', 'dialog:openDocument']);
const events = Object.freeze(['core:event']);

function assertChannel(channel, allowed) {
  if (!allowed.includes(channel)) throw new Error(`Unsupported IPC channel: ${channel}`);
}

contextBridge.exposeInMainWorld('sori', {
  invoke(channel, ...args) {
    assertChannel(channel, commands);
    return ipcRenderer.invoke(channel, ...args);
  },
  onEvent(channel, listener) {
    assertChannel(channel, events);
    const wrapped = (_event, payload) => listener(payload);
    ipcRenderer.on(channel, wrapped);
    return () => ipcRenderer.removeListener(channel, wrapped);
  },
});
