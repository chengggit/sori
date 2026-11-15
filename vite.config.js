import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";
import { sveltekit } from "@sveltejs/kit/vite";
// @ts-expect-error type error without @types/node package
import process from "node:process";
const host = process.env.TAURI_DEV_HOST;

// video-tauri 0.3.0 sends CSS pixels to GTK. Convert via device pixels so
// WebKit zoom and the window's display scale are both accounted for.
/** @returns {import("vite").Plugin} */
function nativeVideoZoom() {
  const entry = "/node_modules/@get-air/video-tauri/dist-js/index.js";
  const original = "const scale = android ? (window.devicePixelRatio || 1) : 1;";
  return {
    name: "sori-native-video-zoom",
    enforce: "pre",
    transform(code, id) {
      if (!id.split("?", 1)[0].endsWith(entry)) return;
      if (!code.includes(original)) {
        this.error("Review Sori's WebKit zoom correction after updating @get-air/video-tauri.");
      }
      return code.replace(
        original,
        `const gtkScale = Number(this.element.dataset.gtkScale);
        const scale = android ? (window.devicePixelRatio || 1)
          : gtkScale > 0 ? (window.devicePixelRatio || 1) / gtkScale : 1;`,
      );
    },
  };
}

// https://vite.dev/config/
export default defineConfig(() => ({
  plugins: [nativeVideoZoom(), tailwindcss(), sveltekit()],
  optimizeDeps: { exclude: ["@get-air/video-tauri"] },

  // Vite options tailored for Tauri development and only applied in `tauri dev` or `tauri build`
  //
  // 1. prevent Vite from obscuring rust errors
  clearScreen: false,
  // 2. tauri expects a fixed port, fail if that port is not available
  server: {
    port: 1420,
    strictPort: true,
    host: host || "127.0.0.1",
    hmr: host
      ? {
          protocol: "ws",
          host,
          port: 1421,
        }
      : undefined,
    watch: {
      // 3. tell Vite to ignore watching `src-tauri`
      ignored: ["**/src-tauri/**"],
    },
  },
}));
