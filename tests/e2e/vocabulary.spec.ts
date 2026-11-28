import { expect, test, type Page } from "@playwright/test";

async function seed(page: Page, mode = "normal") {
  await page.addInitScript(
    ({ mode }) => {
      const host = window as any;
      host.vocabFail = mode === "error";
      host.vocabEditFail = false;
      host.vocabRemoveFail = false;
      host.vocabSlow = false;
      host.vocabCalls = [];
      host.vocabEntries =
        mode === "empty"
          ? []
          : [
              {
                id: 1,
                word: "개발했다고",
                normalizedForm: "개발하다",
                documentId: null,
                sourceTitle: "KAIST",
                context: "새로운 기술을 개발했다고 밝혔다.",
                createdAt: 1795800000,
                definition: {
                  term: "개발하다",
                  partOfSpeech: "verb",
                  hanja: "開發하다",
                  text: "develop; exploit — To make land, natural resources, etc., useful, or easy to utilize.",
                  sourceUrl: "https://krdict.korean.go.kr/eng",
                  note: "Science vocabulary",
                },
                tags: ["reading", "science"],
              },
              {
                id: 2,
                word: "학교",
                normalizedForm: null,
                documentId: 9,
                sourceTitle: "한국 생활",
                context: "학교에 갔어요.",
                createdAt: 1795800010,
                definition: null,
                tags: ["nouns"],
              },
              {
                id: 3,
                word: "아름다운",
                normalizedForm: "아름답다",
                documentId: null,
                sourceTitle: "Korean conversation",
                context: "아름다운 세상이네요.",
                createdAt: 1795800020,
                definition: {
                  term: "아름답다",
                  partOfSpeech: "adjective",
                  text: "beautiful",
                  sourceUrl: "",
                  note: null,
                },
                tags: [],
              },
            ];
      let listeners: ((payload: any) => void)[] = [];
      host.emitVocabChange = () => listeners.forEach((fn) => fn({ name: "library-changed" }));
      host.sori = {
        onEvent: (_name: string, fn: (payload: any) => void) => {
          listeners.push(fn);
          return () => (listeners = listeners.filter((x) => x !== fn));
        },
        invoke: async (channel: string, command: any, payload: any) => {
          const name = channel === "core:invoke" ? command : channel;
          const input = channel === "core:invoke" ? payload : command;
          host.vocabCalls.push({ name, input });
          if (name === "library:state") {
            if (host.vocabFail) return { ok: false, data: null, error: "Could not read saved words." };
            return {
              ok: true,
              data: {
                documents: [],
                videos: [],
                youtubeHistory: [],
                vocabulary: structuredClone(host.vocabEntries),
                error: "",
              },
              error: "",
            };
          }
          if (name === "vocabulary:edit") {
            const draft = input.input;
            if (host.vocabSlow) await new Promise((resolve) => setTimeout(resolve, 700));
            if (host.vocabEditFail)
              return { ok: false, data: null, error: "Could not update saved word." };
            if (draft.note && !draft.meaning)
              return { ok: false, data: null, error: "Enter a meaning to save a note." };
            const word = host.vocabEntries.find((x: any) => x.id === input.id);
            word.normalizedForm = draft.normalizedForm || null;
            word.tags = draft.tags;
            word.definition = draft.meaning
              ? { ...word.definition, text: draft.meaning, note: draft.note || null }
              : null;
          }
          if (name === "vocabulary:remove") {
            if (host.vocabRemoveFail)
              return { ok: false, data: null, error: "Could not remove saved word." };
            host.vocabEntries = host.vocabEntries.filter((x: any) => x.id !== input.id);
          }
          return { ok: true, data: null, error: "" };
        },
      };
    },
    { mode },
  );
  await page.goto("/#/vocabulary");
}

test("Vocabulary searches Korean forms, meaning, notes, tags and source snapshots with type/sort controls", async ({
  page,
}) => {
  await seed(page);
  await expect(page.getByTestId("vocabulary-count")).toHaveText("3 saved words");
  await expect(page.getByTestId("vocabulary-2")).toContainText("학교");
  for (const query of [
    "개발했다고",
    "개발하다".normalize("NFD"),
    "exploit",
    "SCIENCE",
    "reading",
    "KAIST",
  ]) {
    await page.getByLabel("Search vocabulary").fill(query);
    await expect(page.getByTestId("word-card-1")).toBeVisible();
    await expect(page.getByTestId("vocabulary-count")).toHaveText("1 of 3 saved words");
  }
  await page.getByLabel("Search vocabulary").fill("");
  await page.getByLabel("Filter by type").selectOption("Noun");
  await expect(page.getByTestId("vocabulary-list").locator("article")).toHaveCount(1);
  await expect(page.getByTestId("vocabulary-2")).toBeVisible();
  await page.getByLabel("Search vocabulary").fill("missing");
  await expect(page.getByTestId("empty-vocabulary")).toContainText("No words match");
  await page.getByRole("button", { name: "Clear filters" }).click();
  await expect(page.getByTestId("vocabulary-count")).toHaveText("3 saved words");
  await expect(page.getByLabel("Search vocabulary")).toBeFocused();
  const order = () =>
    page
      .getByTestId("vocabulary-list")
      .locator("article")
      .evaluateAll((nodes) => nodes.map((node) => node.getAttribute("data-testid")));
  expect(await order()).toEqual(["word-card-3", "word-card-2", "word-card-1"]);
  await page.getByLabel("Sort vocabulary").selectOption("Oldest");
  expect(await order()).toEqual(["word-card-1", "word-card-2", "word-card-3"]);
  await page.getByLabel("Sort vocabulary").selectOption("A–Z");
  expect(await order()).toEqual(["word-card-1", "word-card-3", "word-card-2"]);
});

test("Details open against the right edge, resize, retain orphaned context and restore focus", async ({
  page,
}) => {
  await seed(page);
  const row = page.getByTestId("vocabulary-1");
  await row.click();
  const details = page.getByTestId("vocabulary-details");
  await expect(details.getByRole("heading", { level: 2 })).toHaveText("개발하다");
  await expect(details).toContainText("開發하다 · Verb");
  await expect(details).toContainText("새로운 기술을 개발했다고 밝혔다.");
  await expect(details).toContainText("KAIST");
  await expect(page.getByRole("button", { name: "Close word details" })).toBeFocused();
  await expect
    .poll(async () => (await details.boundingBox())!.x + (await details.boundingBox())!.width)
    .toBeCloseTo(1280, 0);
  const resizer = page.getByRole("separator", { name: "Resize word details" });
  const width = Number(await resizer.getAttribute("aria-valuenow"));
  await resizer.focus();
  await page.keyboard.press("ArrowLeft");
  await expect(resizer).toHaveAttribute("aria-valuenow", String(width + 16));
  await page.keyboard.press("Home");
  await expect(resizer).toHaveAttribute("aria-valuenow", "320");
  await page.keyboard.press("Escape");
  await expect(details).toHaveCount(0);
  await expect(row).toBeFocused();
});

test("Failed edits retain drafts and successful edits refresh the selected details", async ({
  page,
}) => {
  await seed(page);
  await page.getByTestId("vocabulary-1").click();
  await page
    .getByTestId("vocabulary-details")
    .getByRole("button", { name: "Edit", exact: true })
    .click();
  const dialog = page.getByRole("dialog", { name: "Edit saved word" });
  await expect(dialog.getByLabel("Dictionary form")).toBeFocused();
  await dialog.getByLabel("Meaning", { exact: true }).fill("develop a technology");
  await dialog.getByLabel("Note", { exact: true }).fill("An updated note");
  await dialog.getByLabel("Tags", { exact: true }).fill("science, reading, science, ");
  await page.evaluate(() => {
    (window as any).vocabEditFail = true;
  });
  await dialog.getByRole("button", { name: "Save changes" }).click();
  await expect(dialog.getByRole("alert")).toContainText("Could not update");
  await expect(dialog.getByLabel("Meaning", { exact: true })).toHaveValue("develop a technology");
  await page.evaluate(() => {
    (window as any).vocabEditFail = false;
    (window as any).vocabSlow = true;
  });
  await dialog.getByRole("button", { name: "Save changes" }).click();
  await expect(dialog.getByRole("button", { name: "Saving…" })).toBeDisabled();
  await page.keyboard.press("Escape");
  await expect(dialog).toBeVisible();
  await expect(dialog.getByRole("button", { name: "Close", exact: true })).toHaveCount(0);
  await expect(dialog).toHaveCount(0);
  const details = page.getByTestId("vocabulary-details");
  await expect(details).toContainText("develop a technology");
  await expect(details).toContainText("An updated note");
  await expect(details).toContainText("KAIST");
  await expect(details.getByRole("button", { name: "Edit", exact: true })).toBeFocused();
  expect(await page.evaluate(() => (window as any).vocabEntries[0].tags)).toEqual([
    "science",
    "reading",
  ]);
});

test("Three-dot edit allows an empty dictionary form and validates notes without losing fields", async ({
  page,
}) => {
  await seed(page);
  await page.getByRole("button", { name: "More actions for 개발하다", exact: true }).click();
  await page.getByRole("menuitem", { name: "Edit", exact: true }).click();
  const dialog = page.getByRole("dialog", { name: "Edit saved word" });
  await expect(dialog.getByLabel("Dictionary form")).toBeFocused();
  await dialog.getByLabel("Dictionary form").fill("");
  await dialog.getByLabel("Meaning", { exact: true }).fill("");
  await dialog.getByRole("button", { name: "Save changes" }).click();
  await expect(dialog.getByRole("alert")).toHaveText("Enter a meaning to save a note.");
  await dialog.getByLabel("Note", { exact: true }).fill("");
  await dialog.getByRole("button", { name: "Save changes" }).click();
  await expect(dialog).toHaveCount(0);
  await expect(page.getByTestId("vocabulary-1")).toContainText("개발했다고");
  await expect(
    page.getByRole("button", { name: "More actions for 개발했다고", exact: true }),
  ).toBeFocused();
  await page.getByTestId("vocabulary-1").click();
  await expect(page.getByTestId("vocabulary-details")).toContainText("No definition saved.");
});

test("Removal keeps entries on cancel/failure and closes details only after success", async ({
  page,
}) => {
  await seed(page);
  await page.getByRole("button", { name: "More actions for 개발하다", exact: true }).click();
  await page.getByRole("menuitem", { name: "Remove", exact: true }).click();
  const dialog = page.getByRole("dialog", { name: "Remove saved word?" });
  await dialog.getByRole("button", { name: "Cancel" }).click();
  await expect(page.getByTestId("vocabulary-1")).toBeVisible();
  await expect(
    page.getByRole("button", { name: "More actions for 개발하다", exact: true }),
  ).toBeFocused();
  await page.getByTestId("vocabulary-1").click();
  await page
    .getByTestId("vocabulary-details")
    .getByRole("button", { name: "Remove", exact: true })
    .click();
  await page.evaluate(() => {
    (window as any).vocabRemoveFail = true;
  });
  await dialog.getByRole("button", { name: "Remove", exact: true }).click();
  await expect(dialog.getByRole("alert")).toContainText("Could not remove");
  await expect(page.getByTestId("vocabulary-details")).toBeVisible();
  await page.evaluate(() => {
    (window as any).vocabRemoveFail = false;
  });
  await dialog.getByRole("button", { name: "Remove", exact: true }).click();
  await expect(dialog).toHaveCount(0);
  await expect(page.getByTestId("vocabulary-1")).toHaveCount(0);
  await expect(page.getByTestId("vocabulary-details")).toHaveCount(0);
  await expect(page.getByLabel("Search vocabulary")).toBeFocused();
});

test("Library notifications update saved words without overwriting an open edit draft", async ({
  page,
}) => {
  await seed(page);
  await page.getByRole("button", { name: "More actions for 개발하다", exact: true }).click();
  await page.getByRole("menuitem", { name: "Edit", exact: true }).click();
  const dialog = page.getByRole("dialog", { name: "Edit saved word" });
  await dialog.getByLabel("Meaning", { exact: true }).fill("My unsaved draft");
  await page.evaluate(() => {
    const host = window as any;
    host.vocabEntries[0].definition.text = "Changed outside the page";
    host.vocabEntries.push({
      ...host.vocabEntries[0],
      id: 4,
      word: "새로 저장한 단어",
      normalizedForm: null,
    });
    host.emitVocabChange();
  });
  await expect(page.getByTestId("vocabulary-count")).toHaveText("4 saved words");
  await expect(dialog.getByLabel("Meaning", { exact: true })).toHaveValue("My unsaved draft");
  await dialog.getByRole("button", { name: "Cancel" }).click();
  await expect(page.getByTestId("vocabulary-1")).toContainText("Changed outside the page");
  await expect(page.getByTestId("vocabulary-4")).toContainText("새로 저장한 단어");
});

test("Empty vocabulary and database errors have distinct states with working retry", async ({
  page,
}) => {
  await seed(page, "empty");
  await expect(page.getByTestId("empty-vocabulary")).toContainText("No saved words yet");
  await expect(page.getByTestId("vocabulary-count")).toHaveText("0 saved words");
  await page.evaluate(() => {
    (window as any).vocabFail = true;
    (window as any).emitVocabChange();
  });
  await expect(page.getByRole("alert")).toContainText("Could not read saved words.");
  await expect(page.getByTestId("empty-vocabulary")).toHaveCount(0);
  await page.evaluate(() => {
    (window as any).vocabFail = false;
  });
  await page.getByRole("button", { name: "Retry", exact: true }).click();
  await expect(page.getByRole("alert")).toHaveCount(0);
  await expect(page.getByTestId("empty-vocabulary")).toBeVisible();
});

test("Vocabulary visual baselines fit themes, details, editing, narrow windows and zoom", async ({
  page,
}) => {
  await seed(page);
  await expect(page.getByTestId("vocabulary-list").locator("article")).toHaveCount(3);
  await page.screenshot({ path: "test-results/vocabulary-baseline/light.png", animations: "disabled" });
  await page.getByTestId("vocabulary-1").click();
  await page
    .getByTestId("vocabulary-details")
    .getByRole("button", { name: "Edit", exact: true })
    .click();
  await page.screenshot({
    path: "test-results/vocabulary-baseline/editor.png",
    animations: "disabled",
  });
  await page.getByRole("dialog").getByRole("button", { name: "Cancel" }).click();
  await page.screenshot({
    path: "test-results/vocabulary-baseline/details.png",
    animations: "disabled",
  });
  await page.evaluate(() => document.documentElement.classList.add("dark"));
  await page.screenshot({ path: "test-results/vocabulary-baseline/dark.png", animations: "disabled" });
  await page.setViewportSize({ width: 600, height: 800 });
  await page.screenshot({
    path: "test-results/vocabulary-baseline/narrow.png",
    animations: "disabled",
  });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true,
  );
  await page.keyboard.press("Control+Shift+Equal");
  await expect(page.locator("html")).toHaveCSS("zoom", "1.1");
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true,
  );
});
