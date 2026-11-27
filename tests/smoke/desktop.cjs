const { execFileSync } = require("node:child_process");
const { writeFileSync } = require("node:fs");
const { join } = require("node:path");
const { tmpdir } = require("node:os");

module.exports = function attachSmokeChecks(window, { app, isDev, smokeHash }) {
  let smokeDone = false;
  function finishSmoke(exitCode, message) {
    if (message) console.error(message);
    app.exit(exitCode);
  }
  const watchdog = setTimeout(
    () => finishSmoke(2, "Smoke check timed out waiting for the page."),
    20_000,
  );
  window.webContents.once("did-fail-load", (_event, code, description) => {
    clearTimeout(watchdog);
    finishSmoke(1, `Smoke check failed to load: ${description} (${code})`);
  });
  window.webContents.once("did-finish-load", async () => {
    if (smokeDone) return;
    smokeDone = true;
    try {
      const title = await window.webContents.executeJavaScript("document.title");
      const mounted = await window.webContents.executeJavaScript(
        'Boolean(document.querySelector("#app > *"))',
      );
      if (title !== "Sori" || !mounted) {
        clearTimeout(watchdog);
        finishSmoke(1);
        return;
      }
      if (smokeHash === "home") {
        const path = join(process.env.SORI_DATA_DIR, "home-smoke.mkv");
        execFileSync(
          app.isPackaged
            ? join(process.resourcesPath, "bin", process.platform === "win32" ? "ffmpeg.exe" : "ffmpeg")
            : "ffmpeg",
          [
            "-v",
            "error",
            "-f",
            "lavfi",
            "-i",
            "color=c=blue:s=320x240:d=4",
            "-pix_fmt",
            "yuv420p",
            "-y",
            path,
          ],
          { timeout: 30000 },
        );
        const seeded = await window.webContents.executeJavaScript(`(async () => {
          const imported = await window.sori.invoke('core:invoke', 'video:import', { path: ${JSON.stringify(path)} });
          if (!imported.ok) throw new Error(imported.error);
          const id = imported.data.id;
          const saved = await window.sori.invoke('core:invoke', 'video:saveProgress', { id, seconds: 1, duration: 4 });
          if (!saved.ok) throw new Error(saved.error);
          const thumbnail = await window.sori.invoke('core:invoke', 'video:thumbnail', { id });
          if (!thumbnail.ok) throw new Error(thumbnail.error);
          return id;
        })()`);
        // Remount Home after seeding the real temporary library.
        await window.webContents.executeJavaScript(`location.hash = '#/library'`);
        await new Promise((resolve) => setTimeout(resolve, 300));
        await window.webContents.executeJavaScript(`location.hash = '#/home'`);
        let result;
        for (let attempt = 0; attempt < 30; attempt++) {
          await new Promise((resolve) => setTimeout(resolve, 300));
          result = await window.webContents.executeJavaScript(`(() => {
            const card = document.querySelector('[data-testid=resume-card]');
            const img = card?.querySelector('img');
            return { text: card?.textContent, loaded: !!img?.naturalWidth, href: card?.querySelector('a')?.getAttribute('href') };
          })()`);
          if (result.loaded) break;
        }
        clearTimeout(watchdog);
        finishSmoke(
          result.loaded && result.href === "#/watch?id=" + seeded ? 0 : 1,
          `Home page: ${JSON.stringify(result)}`,
        );
        return;
      }
      if (smokeHash === "settings") {
        await window.webContents.executeJavaScript(`location.hash = '#/settings'`);
        for (let attempt = 0; attempt < 20; attempt += 1) {
          await new Promise((resolve) => setTimeout(resolve, 300));
          const ready = await window.webContents.executeJavaScript(
            'Boolean(document.querySelector("[data-testid=appearance-settings]"))',
          );
          if (ready) break;
        }
        await window.webContents.executeJavaScript(
          'document.querySelector("[data-testid=settings-theme-dark]").click()',
        );
        await new Promise((resolve) => setTimeout(resolve, 300));
        const state = await window.webContents.executeJavaScript(`(() => ({
        dark: document.documentElement.classList.contains('dark'),
        sections: ['appearance-settings', 'dictionary-settings', 'youtube-settings', 'embed-settings']
          .filter((id) => document.querySelector('[data-testid=' + id + ']')).length,
      }))()`);
        clearTimeout(watchdog);
        finishSmoke(state.dark && state.sections === 4 ? 0 : 1, `Settings: ${JSON.stringify(state)}`);
        return;
      }
      if (smokeHash === "youtube") {
        const settings = await window.webContents.executeJavaScript(`(async () => {
        const before = await window.sori.invoke('core:invoke', 'youtube:settings', {});
        const saved = await window.sori.invoke('core:invoke', 'youtube:saveKey', { key: 'AIzaTestKey123456' });
        const after = await window.sori.invoke('core:invoke', 'youtube:settings', {});
        await window.sori.invoke('core:invoke', 'youtube:removeKey', {});
        const cleared = await window.sori.invoke('core:invoke', 'youtube:settings', {});
        return {
          before: before.data.saved,
          saved: saved.ok,
          after: after.data.saved,
          cleared: cleared.data.saved,
        };
      })()`);
        await window.webContents.executeJavaScript(`location.hash = '#/explore'`);
        for (let attempt = 0; attempt < 20; attempt += 1) {
          await new Promise((resolve) => setTimeout(resolve, 300));
          const ready = await window.webContents.executeJavaScript(
            'Boolean(document.querySelector("[aria-label=\\"YouTube link\\"]"))',
          );
          if (ready) break;
        }
        await window.webContents.executeJavaScript(`(() => {
        const field = document.querySelector('[aria-label="YouTube link"]');
        const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
        setter.call(field, 'https://youtu.be/dQw4w9WgXcQ');
        field.dispatchEvent(new Event('input', { bubbles: true }));
      })()`);
        await window.webContents.executeJavaScript(`(() => {
        const play = [...document.querySelectorAll('button')].find((node) => node.textContent.trim() === 'Play');
        play?.click();
      })()`);
        await new Promise((resolve) => setTimeout(resolve, 800));
        const src = await window.webContents.executeJavaScript(
          'document.querySelector("[data-testid=youtube-player] iframe")?.src ?? ""',
        );
        clearTimeout(watchdog);
        finishSmoke(
          !settings.before &&
            settings.saved &&
            settings.after &&
            !settings.cleared &&
            src.includes("dQw4w9WgXcQ")
            ? 0
            : 1,
          `YouTube: ${JSON.stringify({ settings, src })}`,
        );
        return;
      }
      if (smokeHash === "dictionary") {
        const settings = await window.webContents.executeJavaScript(`(async () => {
        const bad = await window.sori.invoke('core:invoke', 'dictionary:saveKey', { key: 'bad' });
        const good = await window.sori.invoke('core:invoke', 'dictionary:saveKey', {
          key: '0123456789abcdef0123456789abcdef',
        });
        const current = await window.sori.invoke('core:invoke', 'dictionary:settings', {});
        await window.sori.invoke('core:invoke', 'dictionary:removeKey', {});
        return { badOk: bad.ok, goodOk: good.ok, provider: current.data.provider, hasKey: current.data.hasKey };
      })()`);
        await window.webContents.executeJavaScript(`(async () => {
        await window.sori.invoke('core:invoke', 'document:add', { title: '사전 스모크', content: '학교에 갔어요.' });
      })()`);
        await window.webContents.executeJavaScript(`location.hash = '#/reader?id=1'`);
        for (let attempt = 0; attempt < 20; attempt += 1) {
          await new Promise((resolve) => setTimeout(resolve, 300));
          const ready = await window.webContents.executeJavaScript(
            'Boolean(document.querySelector("[data-testid^=token-]"))',
          );
          if (ready) break;
        }
        await window.webContents.executeJavaScript(
          'document.querySelector("[data-testid^=token-]")?.click()',
        );
        await new Promise((resolve) => setTimeout(resolve, 300));
        await window.webContents.executeJavaScript(
          'document.querySelector("[data-testid^=lookup-]")?.click()',
        );
        await new Promise((resolve) => setTimeout(resolve, 800));
        const panel = await window.webContents.executeJavaScript(
          'Boolean(document.querySelector("[data-testid=dictionary-panel]"))',
        );
        const tabs = await window.webContents.executeJavaScript(
          'document.querySelectorAll("[data-testid^=embed-tab-]").length',
        );
        clearTimeout(watchdog);
        finishSmoke(
          !settings.badOk &&
            settings.goodOk &&
            settings.provider === "wiktionary" &&
            settings.hasKey &&
            panel &&
            tabs === 2
            ? 0
            : 1,
          `Dictionary: ${JSON.stringify({ settings, panel, tabs })}`,
        );
        return;
      }
      if (smokeHash === "subtitles") {
        const directory = process.env.SORI_DATA_DIR || tmpdir();
        const srtPath = join(directory, "sori-subs.srt");
        const videoPath = join(directory, "sori-subs.mkv");
        writeFileSync(
          srtPath,
          "1\n00:00:00,000 --> 00:00:03,000\n안녕하세요\n\n" +
            "2\n00:00:03,000 --> 00:00:06,000\n학교에 갔어요\n",
        );
        execFileSync(
          "ffmpeg",
          [
            "-v",
            "error",
            "-f",
            "lavfi",
            "-i",
            "color=c=blue:s=320x240:d=6",
            "-i",
            srtPath,
            "-map",
            "0:v",
            "-map",
            "1:s",
            "-c:s",
            "srt",
            "-pix_fmt",
            "yuv420p",
            "-metadata:s:s:0",
            "language=kor",
            "-metadata:s:s:0",
            "title=Korean",
            "-y",
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
        let caption = "";
        for (let attempt = 0; attempt < 30; attempt += 1) {
          await new Promise((resolve) => setTimeout(resolve, 300));
          caption = await window.webContents.executeJavaScript(
            'document.querySelector("[data-testid=primary-caption]")?.textContent ?? ""',
          );
          if (caption.includes("안녕하세요")) break;
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
          caption.includes("안녕하세요") && analysis.includes("Ending") && position >= 3 && transcript
            ? 0
            : 1,
          `Subtitles: ${JSON.stringify({ caption, analysis, position, transcript })}`,
        );
        return;
      }
      if (smokeHash === "watch") {
        const videoPath = join(process.env.SORI_DATA_DIR || tmpdir(), "sori-smoke.mkv");
        execFileSync(
          "ffmpeg",
          [
            "-v",
            "error",
            "-f",
            "lavfi",
            "-i",
            "color=c=blue:s=320x240:d=4",
            "-pix_fmt",
            "yuv420p",
            "-y",
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
        finishSmoke(
          ready && currentTime > 0 && saved > 0 ? 0 : 1,
          `Watch page: ${JSON.stringify({ id, ready, currentTime, saved })}`,
        );
        return;
      }
      if (smokeHash === "pdf") {
        const fixture = join(process.cwd(), "tests", "fixtures", "pdf-rendering.pdf");
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
        let spans = 0;
        for (let attempt = 0; attempt < 20; attempt += 1) {
          await new Promise((resolve) => setTimeout(resolve, 300));
          spans = await window.webContents.executeJavaScript(
            'document.querySelectorAll("[data-testid=pdf-container] .textLayer span").length',
          );
          if (spans > 0) break;
        }
        let analysis = "";
        if (spans > 0) {
          await window.webContents.executeJavaScript(
            'document.querySelector("[data-testid=pdf-container] .textLayer span").click()',
          );
          for (let attempt = 0; attempt < 20; attempt += 1) {
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
        finishSmoke(
          id > 0 && pages > 0 && scrollPages > 0 && !problem && analysis ? 0 : 1,
          `PDF page: ${JSON.stringify({ id, pages, spans, analysis, scrollPages, problem })}`,
        );
        return;
      }
      if (smokeHash === "vocabulary") {
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
        finishSmoke(
          meaning === "hello" && remaining === 0 ? 0 : 1,
          `Vocabulary page: ${JSON.stringify({ meaning, dialogVisible, remaining })}`,
        );
        return;
      }
      if (smokeHash === "reader") {
        const id = await window.webContents.executeJavaScript(`(async () => {
        await window.sori.invoke('core:invoke', 'document:add', { title: '리더 스모크', content: '학교에 갔어요. '.repeat(60) });
        const state = await window.sori.invoke('core:invoke', 'library:state', {});
        return state.data.documents[0].id;
      })()`);
        await window.webContents.executeJavaScript(`location.hash = '#/reader?id=${id}'`);
        for (let attempt = 0; attempt < 20; attempt += 1) {
          await new Promise((resolve) => setTimeout(resolve, 300));
          const ready = await window.webContents.executeJavaScript(
            'Boolean(document.querySelector("[data-testid^=token-]"))',
          );
          if (ready) break;
        }
        await window.webContents.executeJavaScript(
          'document.querySelector("[data-testid^=token-]")?.click()',
        );
        let panel = "";
        for (let attempt = 0; attempt < 20; attempt += 1) {
          await new Promise((resolve) => setTimeout(resolve, 300));
          panel = await window.webContents.executeJavaScript(
            'document.querySelector("[data-testid=reader-analysis]")?.textContent ?? ""',
          );
          if (panel.includes("학교")) break;
        }
        await window.webContents.executeJavaScript(`(() => {
        const save = [...document.querySelectorAll('[data-testid=analysis-panel] button')]
          .find((node) => node.textContent.includes('Save word'));
        save?.click();
      })()`);
        let vocabulary = 0;
        for (let attempt = 0; attempt < 10; attempt += 1) {
          await new Promise((resolve) => setTimeout(resolve, 300));
          vocabulary = await window.webContents.executeJavaScript(`(async () => {
          const state = await window.sori.invoke('core:invoke', 'library:state', {});
          return state.data.vocabulary.length;
        })()`);
          if (vocabulary >= 1) break;
        }
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
        finishSmoke(
          panel.includes("학교") && vocabulary >= 1 && position > 0.4 ? 0 : 1,
          `Reader page: ${JSON.stringify({ panel, vocabulary, position })}`,
        );
        return;
      }
      if (smokeHash === "library") {
        await window.webContents.executeJavaScript(
          `window.sori.invoke('core:invoke', 'document:add', { title: '스모크 문서', content: '안녕하세요' })`,
        );
        await window.webContents.executeJavaScript(`location.hash = '#/library'`);
        let listed = "";
        for (let attempt = 0; attempt < 10; attempt += 1) {
          await new Promise((resolve) => setTimeout(resolve, 300));
          listed = await window.webContents.executeJavaScript(
            'document.querySelector("[data-testid=document-list]")?.textContent ?? ""',
          );
          if (listed.includes("스모크 문서")) break;
        }
        clearTimeout(watchdog);
        finishSmoke(listed.includes("스모크 문서") ? 0 : 1, `Library page: ${listed}`);
        return;
      }
      if (smokeHash === "analysis") {
        let result = { panel: false, terms: "", error: "" };
        for (let attempt = 0; attempt < 20; attempt += 1) {
          await new Promise((resolve) => setTimeout(resolve, 300));
          result = await window.webContents.executeJavaScript(`(() => {
          const panel = document.querySelector('[data-testid=analysis-panel]');
          const error = document.querySelector('[data-testid=analysis-error]');
          return { panel: Boolean(panel), terms: panel ? panel.textContent : '', error: error ? error.textContent : '' };
        })()`);
          if (result.panel && result.terms.includes("학교")) break;
        }
        clearTimeout(watchdog);
        finishSmoke(
          result.panel && !result.error && result.terms.includes("학교") ? 0 : 1,
          `Analysis page: ${JSON.stringify(result)}`,
        );
        return;
      }
      if (smokeHash === "bridge") {
        let values = [];
        for (let attempt = 0; attempt < 20; attempt += 1) {
          await new Promise((resolve) => setTimeout(resolve, 300));
          values = await window.webContents.executeJavaScript(
            '[...document.querySelectorAll("[data-testid^=bridge-]")].map((node) => node.textContent)',
          );
          if (values.length === 3 && values.every((value) => value && value !== "waiting…")) break;
        }
        const populated = values.length === 3 && values.every((value) => value && value !== "waiting…");
        const analyzed = !isDev || String(values[1]).includes("NNG");
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
};
