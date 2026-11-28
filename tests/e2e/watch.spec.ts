import { expect, test, type Page } from "@playwright/test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const videoDirectory = mkdtempSync(join(tmpdir(), "sori-watch-browser-"));
let media: Buffer;
try {
  const target = join(videoDirectory, "sample.webm");
  execFileSync(require("ffmpeg-static"), [
    "-v",
    "error",
    "-f",
    "lavfi",
    "-i",
    "color=c=0x284c52:s=640x360:r=5:d=30",
    "-c:v",
    "libvpx-vp9",
    "-g",
    "5",
    target,
  ]);
  media = readFileSync(target);
} finally {
  rmSync(videoDirectory, { recursive: true, force: true });
}
async function seed(page: Page, youtube = false) {
  await page.route("**/watch-fixture.webm", (route) => {
    const range = /^bytes=(\d+)-(\d*)$/.exec(route.request().headers().range ?? "");
    const start = Number(range?.[1] ?? 0),
      end = Math.min(Number(range?.[2] || media.length - 1), media.length - 1);
    return route.fulfill({
      status: range ? 206 : 200,
      headers: {
        "Content-Type": "video/webm",
        "Accept-Ranges": "bytes",
        ...(range ? { "Content-Range": `bytes ${start}-${end}/${media.length}` } : {}),
      },
      body: media.subarray(start, end + 1),
    });
  });
  await page.route("https://www.youtube.com/embed/**", (route) =>
    route.fulfill({ contentType: "text/html", body: "<p>YouTube fixture</p>" }),
  );
  await page.addInitScript(() => {
    (window as any).watchCalls = [];
    let saved: any = null,
      text: any = {};
    const cues = Array.from({ length: 24 }, (_, i) => ({
      start: i,
      end: i + 1,
      text: "학교에 갔어요.",
    }));
    const vtt = (english = false) =>
      "WEBVTT\n\n" +
      cues
        .map(
          (c, i) =>
            `00:00:${String(i).padStart(2, "0")}.000 --> 00:00:${String(i + 1).padStart(2, "0")}.000\n${english ? "We went to school." : c.text}`,
        )
        .join("\n\n");
    const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
    (window as any).sori = {
      onEvent: () => () => {},
      invoke: async (channel: string, command: any, payload: any) => {
        const native = channel !== "core:invoke";
        const name = native ? channel : command;
        const dataIn = native ? command : payload;
        (window as any).watchCalls.push({ name, payload: dataIn });
        let data: any = null;
        if (name === "video:read")
          data = { path: `/movie-${dataIn.id}.webm`, seconds: 2, sidecar: null };
        if (name === "video:expose")
          data = {
            id: command,
            url: location.origin + "/watch-fixture.webm",
            name: command.includes("movie-3") ? "Third.webm" : "Take Charge of My Heart S01E03.webm",
          };
        if (name === "video:probe" && String(command).includes("movie-2")) await delay(350);
        if (name === "video:probe")
          data = {
            tracks: [
              { index: 1, language: "kor", label: "Korean" },
              { index: 2, language: "eng", label: "English" },
              { index: 3, language: "kor", label: "Alternative" },
            ],
          };
        if (name === "video:track") {
          if (payload === 3) await delay(250);
          data = vtt(payload === 2);
        }
        if (name === "video:attach")
          data = { path: "/captions.srt", name: "captions.srt", text: vtt() };
        if (name === "dialog:openTranscript") {
          if ((window as any).cancelPicker) return null;
          data = "/transcript.txt";
        }
        if (name === "video:readTranscript") data = text;
        if (name === "video:saveTranscript") {
          text = { title: "transcript.txt", content: "학교에 갔어요.\n\n".repeat(100), position: 0 };
          data = text;
        }
        if (name === "video:removeTranscript") text = {};
        if (name === "analyzeText")
          data = [
            { form: "학교", tag: "NNG", start: 0, end: 2, surface: "학교" },
            { form: "에", tag: "JKB", start: 2, end: 3, surface: "에" },
          ];
        if (name === "dictionary:settings") data = { provider: "wiktionary" };
        if (name === "dictionary:lookup")
          data = [
            {
              term: "학교",
              text: "school",
              partOfSpeech: "noun",
              sourceUrl: "https://en.wiktionary.org/wiki/학교",
            },
          ];
        if (name === "vocabulary:find") data = saved;
        if (name === "vocabulary:save") {
          saved = { id: 1, ...dataIn.input };
          data = saved;
        }
        if (name === "library:state")
          data = {
            youtubeHistory: [{ youtubeId: "dQw4w9WgXcQ", seconds: 2, title: "YouTube sample" }],
          };
        if (name === "youtube:metadata") data = { title: "YouTube sample", channel: "Korean" };
        if (name === "youtube:transcript" || name === "youtube:fetchTranscript")
          data = { cues, language: "ko" };
        return native ? data : { ok: true, data, error: "" };
      },
    };
    (window as any).YT = {
      Player: class {
        timer: any;
        time = 2;
        constructor(_frame: any, options: any) {
          setTimeout(() => options.events.onReady({ target: this }), 0);
          (this as any).options = options;
        }
        getCurrentTime() {
          return this.time;
        }
        getDuration() {
          return 30;
        }
        seekTo(value: number) {
          this.time = value;
        }
        playVideo() {
          (this as any).options.events.onStateChange({ data: 1, target: this });
        }
        pauseVideo() {
          (this as any).options.events.onStateChange({ data: 2, target: this });
        }
        destroy() {}
      },
    };
  });
  await page.setViewportSize({ width: 1908, height: 1030 });
  await page.goto(youtube ? "/#/watch?v=dQw4w9WgXcQ" : "/#/watch?id=1");
  if (!youtube) await expect(page.getByRole("button", { name: "Play", exact: true })).toBeEnabled();
  await expect(page.getByTestId("transcript")).toBeVisible();
}

test("Qt Watch column, overlay controls, tracks, captions, seek and progress", async ({ page }) => {
  await seed(page);
  await expect(page.getByTestId("watch-title")).toHaveText("Take Charge of My Heart S01E03");
  const stage = (await page.getByTestId("watch-stage").boundingBox())!;
  const transcript = (await page.getByTestId("transcript").boundingBox())!;
  expect(transcript.y).toBeGreaterThan(stage.y + stage.height);
  await expect(page.getByTestId("primary-caption")).toContainText("학교");
  await expect(page.getByTestId("secondary-caption")).toHaveText("We went to school.");
  await page.getByRole("button", { name: "Subtitle and audio settings" }).click();
  await page.getByLabel("Primary subtitle track").selectOption("off");
  await expect(page.getByTestId("primary-caption")).toHaveCount(0);
  await page.getByLabel("Primary subtitle track").selectOption("index:1");
  await expect(page.getByTestId("primary-caption")).toBeVisible();
  await page.getByLabel("Show subtitles").uncheck();
  await expect(page.getByTestId("primary-caption")).toHaveCount(0);
  await page.getByLabel("Show subtitles").check();
  await page.keyboard.press("Escape");
  await page.getByTestId("cue-8").click();
  await expect
    .poll(() => page.getByTestId("video").evaluate((v: HTMLVideoElement) => v.currentTime))
    .toBeCloseTo(8, 0);
  await page.getByRole("button", { name: "Play", exact: true }).click();
  await expect(page.getByRole("button", { name: "Pause", exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Pause", exact: true }).click();
  await expect
    .poll(() =>
      page.evaluate(() =>
        (window as any).watchCalls.some(
          (c: any) => c.name === "video:saveProgress" && c.payload.seconds >= 8,
        ),
      ),
    )
    .toBe(true);
});

test("caption lookup pauses and resumes playback; full sidebar saves video context", async ({
  page,
}) => {
  await seed(page);
  await page.getByRole("button", { name: "Play", exact: true }).click();
  await page.getByTestId("primary-caption").getByRole("button", { name: "Analyze 학교에" }).click();
  await expect(page.getByTestId("caption-definition")).toContainText("school");
  await expect(page.getByRole("button", { name: "Play", exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Close subtitle definition" }).click();
  await expect(page.getByRole("button", { name: "Pause", exact: true })).toBeVisible();
  await page.getByTestId("primary-caption").getByRole("button", { name: "Analyze 학교에" }).click();
  await page.getByRole("button", { name: "Open full analysis" }).click();
  await expect(page.getByTestId("watch-analysis")).toBeVisible();
  await page.getByRole("button", { name: "Save word", exact: true }).click();
  await page
    .getByTestId("save-word-editor")
    .getByRole("button", { name: "Save word", exact: true })
    .click();
  await expect(page.getByTestId("save-word-editor")).toHaveCount(0);
  expect(
    await page.evaluate(
      () => (window as any).watchCalls.find((c: any) => c.name === "vocabulary:save").payload,
    ),
  ).toMatchObject({ kind: "local", id: 1, input: { context: "학교에 갔어요." } });
  await page.keyboard.press("Escape");
  await expect(page.getByTestId("watch-analysis")).toHaveCount(0);
});

test("attached subtitles persist; superseded subtitle extraction cannot restore an off track", async ({
  page,
}) => {
  await seed(page);
  await page.getByRole("button", { name: "Subtitle and audio settings" }).click();
  await page.getByLabel("Primary subtitle track").selectOption("index:3");
  await page.getByLabel("Primary subtitle track").selectOption("off");
  await page.waitForTimeout(350);
  await expect(page.getByTestId("primary-caption")).toHaveCount(0);
  await page.getByTestId("attach-subtitles").click();
  await expect(page.getByLabel("Primary subtitle track")).toHaveValue("attached");
  expect(
    await page.evaluate(() =>
      (window as any).watchCalls.some(
        (c: any) => c.name === "video:saveSubtitles" && c.payload.path === "/captions.srt",
      ),
    ),
  ).toBe(true);
});

test("text transcript import, display toggle, replacement and removal", async ({ page }) => {
  await seed(page);
  await page.getByRole("button", { name: "Add transcript", exact: true }).click();
  await expect(page.getByTestId("text-transcript")).toContainText("학교에 갔어요.");
  await page.getByRole("button", { name: "Show subtitles", exact: true }).click();
  await expect(page.getByTestId("transcript")).toBeVisible();
  await page.getByRole("button", { name: "Show text", exact: true }).click();
  await page.getByRole("button", { name: "Transcript options" }).click();
  await page.getByRole("button", { name: "Replace transcript (.txt)" }).click();
  await expect(page.getByTestId("text-transcript")).toBeVisible();
  await page.getByRole("button", { name: "Transcript options" }).click();
  await page.getByRole("button", { name: "Remove transcript", exact: true }).click();
  await expect(page.getByRole("button", { name: "Add transcript", exact: true })).toBeVisible();
});

test("manual transcript scrolling pauses follow, resumes and fullscreen preserves lookup access", async ({
  page,
}) => {
  await seed(page);
  await page.getByTestId("transcript").hover();
  await page.mouse.wheel(0, 200);
  await expect(page.getByTestId("resume-follow")).toBeVisible();
  await page.getByTestId("resume-follow").click();
  await expect(page.getByTestId("resume-follow")).toHaveCount(0);
  await page.getByRole("button", { name: "Fullscreen", exact: true }).click();
  await expect(page.getByRole("button", { name: "Exit fullscreen", exact: true })).toBeVisible();
  await page.getByTestId("primary-caption").getByRole("button", { name: "Analyze 학교에" }).click();
  await page.getByRole("button", { name: "Open full analysis" }).click();
  await expect(page.getByTestId("watch-analysis")).toBeVisible();
  expect(
    await page
      .getByTestId("watch-analysis")
      .evaluate((el) => !!document.fullscreenElement?.contains(el)),
  ).toBe(true);
  await page.getByRole("button", { name: "Close analysis", exact: true }).click();
  await page.getByRole("button", { name: "Exit fullscreen", exact: true }).click();
});

test("YouTube destination shares transcript and saves source-specific words", async ({ page }) => {
  await seed(page, true);
  await expect(page.getByTestId("youtube-player")).toBeVisible();
  await page.getByTestId("transcript").getByRole("button", { name: "Analyze 학교에" }).first().click();
  await page.getByRole("button", { name: "Save word", exact: true }).click();
  await page
    .getByTestId("save-word-editor")
    .getByRole("button", { name: "Save word", exact: true })
    .click();
  await expect
    .poll(() =>
      page.evaluate(
        () => (window as any).watchCalls.find((c: any) => c.name === "vocabulary:save")?.payload,
      ),
    )
    .toMatchObject({ kind: "youtube", id: "dQw4w9WgXcQ", title: "YouTube sample" });
});

test("Watch visual baselines in light, dark and narrow windows", async ({ page }) => {
  await seed(page);
  await page.screenshot({ path: "test-results/watch-baseline/light.png", animations: "disabled" });
  await page.getByRole("button", { name: "Subtitle and audio settings" }).click();
  await page.screenshot({ path: "test-results/watch-baseline/cc.png", animations: "disabled" });
  await page.keyboard.press("Escape");
  await page.evaluate(() => {
    document.documentElement.classList.add("dark");
  });
  await page.screenshot({ path: "test-results/watch-baseline/dark.png", animations: "disabled" });
  await page.setViewportSize({ width: 800, height: 800 });
  await page.screenshot({ path: "test-results/watch-baseline/narrow.png", animations: "disabled" });
});

test("Watch shortcuts, mute, and leaving a video preserve progress without stale track replies", async ({
  page,
}) => {
  await seed(page);
  await page.keyboard.press("Escape");
  expect(await page.evaluate(() => document.fullscreenElement)).toBeNull();
  await page.getByRole("button", { name: "Mute", exact: true }).click();
  expect(await page.getByTestId("video").evaluate((v: HTMLVideoElement) => v.muted)).toBe(true);
  await page.evaluate(() => (document.activeElement as HTMLElement)?.blur());
  await page.keyboard.press("ArrowRight");
  await expect
    .poll(() => page.getByTestId("video").evaluate((v: HTMLVideoElement) => v.currentTime))
    .toBeCloseTo(7, 0);
  await page.keyboard.press("c");
  await expect(page.getByTestId("primary-caption")).toHaveCount(0);
  await page.keyboard.press("c");
  await page.keyboard.press("Space");
  await expect(page.getByRole("button", { name: "Pause", exact: true })).toBeVisible();
  await page.keyboard.press("Space");
  await page.evaluate(() => {
    location.hash = "/watch?id=2";
  });
  await expect
    .poll(() =>
      page.evaluate(() =>
        (window as any).watchCalls.some(
          (c: any) => c.name === "video:probe" && String(c.payload).includes("movie-2"),
        ),
      ),
    )
    .toBe(true);
  await page.evaluate(() => {
    location.hash = "/watch?id=3";
  });
  await expect(page.getByTestId("watch-title")).toHaveText("Third");
  await page.waitForTimeout(400);
  expect(
    await page.evaluate(() =>
      (window as any).watchCalls.some(
        (c: any) => c.name === "video:track" && String(c.payload).includes("movie-2"),
      ),
    ),
  ).toBe(false);
  expect(
    await page.evaluate(() =>
      (window as any).watchCalls.some(
        (c: any) => c.name === "video:saveProgress" && c.payload.id === 1 && c.payload.seconds >= 7,
      ),
    ),
  ).toBe(true);
});
