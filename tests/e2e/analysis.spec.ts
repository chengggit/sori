import { expect, test, type Page } from "@playwright/test";
async function seed(page: Page, offline = false, provider = "wiktionary") {
  await page.addInitScript(
    ({ offline, provider }) => {
      let saved: any = null;
      const definition = (text: string) => ({
        term: "개발하다",
        text,
        hanja: "開發하다",
        partOfSpeech: "verb",
        sourceUrl: "https://en.wiktionary.org/wiki/개발하다",
        note: null,
      });
      (window as any).analysisCalls = [];
      (window as any).failSave = false;
      (window as any).sori = {
        invoke: async (channel: string, command: string, payload: any) => {
          if (channel === "shell:openExternal") return null;
          (window as any).analysisCalls.push({ command, payload });
          let data: any = null;
          if (command === "document:read") data = { content: "개발했다고", pdfPath: null, position: 0 };
          if (command === "analyzeText")
            data = [
              { form: "개발", tag: "NNG", start: 0, end: 2, surface: "개발" },
              { form: "하", tag: "XSV", start: 2, end: 3, surface: "했" },
              { form: "었", tag: "EP", start: 2, end: 3, surface: "했" },
              { form: "다고", tag: "EF", start: 3, end: 5, surface: "다고" },
            ];
          if (command === "dictionary:settings") data = { provider, hasKey: provider === "krdict" };
          if (command === "dictionary:lookup") {
            if (offline || (window as any).lookupFail)
              return { ok: false, data: null, error: "Dictionary is offline." };
            data =
              payload.provider !== "krdict" && payload.term === "개발하다"
                ? [
                    definition(
                      "develop; exploit — To make land, natural resources, etc., useful, or easy to utilize.",
                    ),
                    definition("develop — To improve one's ability, knowledge, etc."),
                    definition(
                      "develop — To improve or expand the economy of a nation or a certain industry.",
                    ),
                    definition("develop — Another meaning"),
                  ]
                : [];
          }
          if (command === "vocabulary:save") {
            if ((window as any).failSave) {
              (window as any).failSave = false;
              return { ok: false, data: null, error: "Could not save. Try again." };
            }
            saved = { id: 9, ...payload.input };
          }
          if (command === "vocabulary:edit")
            saved = {
              ...saved,
              normalizedForm: payload.input.normalizedForm,
              tags: payload.input.tags,
              definition: {
                ...saved.definition,
                text: payload.input.meaning,
                note: payload.input.note,
              },
            };
          if (command === "vocabulary:remove") saved = null;
          if (command === "vocabulary:find") data = saved;
          return { ok: true, data, error: "" };
        },
        onEvent: () => () => {},
      };
    },
    { offline, provider },
  );
  await page.route("https://korean.dict.naver.com/**", (route) =>
    route.fulfill({ contentType: "text/html", body: "<h1>Naver dictionary</h1>" }),
  );
  await page.goto("/#/reader?id=1");
  await page.getByTestId("token-0").click();
}

test("automatic lemma lookup, selectable meanings, saved definitions and editable vocabulary", async ({
  page,
}) => {
  await seed(page);
  await expect(page.getByTestId("dictionary-definitions").getByRole("button")).toHaveCount(3);
  await page.getByRole("button", { name: "See 1 more meaning" }).click();
  await expect(page.getByTestId("dictionary-definitions").getByRole("button")).toHaveCount(4);
  await page.getByRole("button", { name: "Select meaning 2", exact: true }).click();
  await page.getByRole("button", { name: "Save word", exact: true }).click();
  await expect(page.getByRole("textbox", { name: "Word", exact: true })).toHaveValue("개발하다");
  await expect(page.getByRole("textbox", { name: "Meanings" })).toHaveValue(/improve one's ability/);
  await page.getByRole("textbox", { name: "Tags", exact: true }).fill("reading, verbs, reading");
  await page.evaluate(() => {
    (window as any).failSave = true;
  });
  await page.getByRole("button", { name: "Save word", exact: true }).click();
  await expect(page.getByRole("alert")).toContainText("Could not save");
  await page.getByRole("button", { name: "Save word", exact: true }).click();
  await expect(page.getByRole("button", { name: "Edit saved word" })).toHaveAttribute(
    "aria-pressed",
    "true",
  );
  const input = await page.evaluate(
    () =>
      (window as any).analysisCalls.find((call: any) => call.command === "vocabulary:save").payload
        .input,
  );
  expect(input.word).toBe("개발했다고");
  expect(input.normalizedForm).toBe("개발하다");
  expect(input.tags).toEqual(["reading", "verbs"]);
  expect(input.definition.sourceUrl).toContain("wiktionary.org");
  await page.getByRole("button", { name: "Edit saved word" }).click();
  await page.getByRole("textbox", { name: "Meanings" }).fill("my saved meaning");
  await page.getByRole("button", { name: "Save changes", exact: true }).click();
  await page.getByRole("button", { name: "Edit saved word" }).click();
  await expect(page.getByRole("textbox", { name: "Meanings" })).toHaveValue("my saved meaning");
  await page.getByRole("button", { name: "Remove saved word" }).click();
  await expect(page.getByRole("button", { name: "Save word", exact: true })).toHaveAttribute(
    "aria-pressed",
    "false",
  );
});

test("lookup failures retain morphology and allow offline custom meanings", async ({ page }) => {
  await seed(page, true);
  await expect(page.getByTestId("dictionary-error")).toContainText("offline");
  await expect(page.getByTestId("analysis-panel")).toContainText("Past tense");
  await page.getByRole("button", { name: "Save word", exact: true }).click();
  await page.getByRole("textbox", { name: "Meanings" }).fill("offline custom meaning");
  await page.getByRole("button", { name: "Save word", exact: true }).click();
  await expect(page.getByTestId("analysis-panel")).toContainText("available offline");
});

test("dictionary tabs retain frames and drafts, reorder by keyboard, and dismiss cleanly", async ({
  page,
}) => {
  await page.clock.install();
  await seed(page);
  await page.getByRole("button", { name: "Save word", exact: true }).click();
  await page.getByRole("textbox", { name: "Meanings" }).fill("draft survives tabs");
  await page.getByTestId("embed-tab-naver-ko").click();
  await expect(page.frameLocator('iframe[title="Naver"]').getByRole("heading")).toHaveText(
    "Naver dictionary",
  );
  await page.getByTestId("analysis-tab").click();
  await expect(page.locator('iframe[title="Naver"]')).toHaveCount(1);
  await page.clock.fastForward(31_000);
  await expect(page.locator('iframe[title="Naver"]')).toHaveCount(0);
  await expect(page.getByRole("textbox", { name: "Meanings" })).toHaveValue("draft survives tabs");
  await page.getByTestId("embed-tab-krdict").focus();
  await page.keyboard.press("Alt+ArrowRight");
  expect(await page.evaluate(() => JSON.parse(localStorage.getItem("sori-embeds")!).enabled)).toEqual([
    "naver-ko",
    "papago",
    "krdict",
  ]);
  await page.getByRole("textbox", { name: "Word", exact: true }).focus();
  await page.keyboard.press("Escape");
  await expect(page.getByTestId("save-word-editor")).toHaveCount(0);
  await page.getByRole("button", { name: "Close analysis" }).click();
  await expect(page.getByTestId("analysis-panel")).toHaveCount(0);
});

test("analysis sidebar stays at the right window edge below the header", async ({ page }) => {
  await page.setViewportSize({ width: 1908, height: 1030 });
  await seed(page);
  const sidebar = page.getByTestId("reader-analysis");
  for (const width of [1908, 800]) {
    await page.setViewportSize({ width, height: 1030 });
    await expect
      .poll(async () => {
        const box = await sidebar.boundingBox();
        return box ? Math.round(box.x + box.width) : 0;
      })
      .toBe(width);
    const box = (await sidebar.boundingBox())!;
    expect(box.y).toBe(56);
    expect(Math.round(box.height + box.y)).toBe(1030);
    expect(box.width).toBe(500);
  }
  await page.getByRole("button", { name: "Close analysis", exact: true }).click();
  await expect(sidebar).toHaveCount(0);
});

test("analysis panel visual baselines", async ({ page }) => {
  await page.setViewportSize({ width: 1908, height: 1030 });
  await seed(page);
  await expect(page.getByRole("button", { name: "Select meaning 1", exact: true })).toBeVisible();
  await page
    .getByTestId("analysis-panel")
    .screenshot({ path: "test-results/analysis-baseline/analysis.png" });
  await page.getByRole("button", { name: "Save word", exact: true }).click();
  await page
    .getByTestId("analysis-panel")
    .screenshot({ path: "test-results/analysis-baseline/save.png" });
});

test("KRDict empty results fall back to Wiktionary while provider errors stay visible", async ({
  page,
}) => {
  await seed(page, false, "krdict");
  await expect(page.getByRole("button", { name: "Select meaning 1", exact: true })).toBeVisible();
  expect(
    await page.evaluate(() =>
      (window as any).analysisCalls.some(
        (call: any) => call.command === "dictionary:lookup" && call.payload.provider === "wiktionary",
      ),
    ),
  ).toBe(true);
});

test("KRDict failures do not silently switch providers", async ({ page }) => {
  await seed(page, true, "krdict");
  await expect(page.getByTestId("dictionary-error")).toContainText("offline");
  expect(
    await page.evaluate(() =>
      (window as any).analysisCalls
        .filter((call: any) => call.command === "dictionary:lookup")
        .map((call: any) => call.payload.provider),
    ),
  ).toEqual(["krdict"]);
});
