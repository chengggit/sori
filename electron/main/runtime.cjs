const { app } = require("electron");
const { join } = require("node:path");
const { homedir } = require("node:os");

// Avoid a userData directory derived from the package name.
app.setName("Sori");

// Qt used QStandardPaths::GenericDataLocation + "/com.sori.app" for the library.
// Match it so existing users keep their data without an export/import step.
function legacyDataDirectory() {
  if (process.env.SORI_DATA_DIR) return process.env.SORI_DATA_DIR;
  if (process.platform === "linux") {
    return join(process.env.XDG_DATA_HOME || join(homedir(), ".local", "share"), "com.sori.app");
  }
  return join(app.getPath("appData"), "com.sori.app");
}

function loadNative() {
  const addonPath = !app.isPackaged
    ? join(app.getAppPath(), "native", "sori-node.node")
    : join(process.resourcesPath, "app.asar.unpacked", "native", "sori-node.node");
  try {
    const addon = require(addonPath);
    const resources = !app.isPackaged
      ? join(app.getAppPath(), "resources", "kiwi")
      : join(process.resourcesPath, "kiwi");
    addon.init(resources);
    addon.initLibrary(app.getPath("userData"));
    return addon;
  } catch (error) {
    console.error("Native core is unavailable:", error.message);
    return null;
  }
}

function toolPath(name) {
  if (!app.isPackaged) return name;
  const directory = join(process.resourcesPath, "bin");
  if (process.platform === "darwin" && name === "ffprobe") {
    return join(directory, "ffprobe", process.arch, "ffprobe");
  }
  return join(directory, process.platform === "win32" ? `${name}.exe` : name);
}

module.exports = { legacyDataDirectory, loadNative, toolPath };
