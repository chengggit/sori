import { expect, test, type Page } from "@playwright/test";

async function seed(page: Page, empty = false) {
  await page.addInitScript(
    ({ empty }) => {
      let documents = empty
        ? []
        : [
            { id: 1, title: "Ep. 162 한국인은 다 아는 무서운 이야기-1".normalize("NFD"), pdf: true },
            { id: 2, title: "KAIST", pdf: false },
          ];
      let videos = empty
        ? []
        : [3, 4, 5].map((id, i) => ({
            id,
            title: `Take.Charge.of.My.Heart.S01E0${3 - i}.1080p`,
            displayTitle: `Take Charge of My Heart S01E0${3 - i}`,
            seconds: [348, 3563, 1591][i],
            duration: [3873, 3569, 3716][i],
            thumbnailUrl: null,
            watchedAt: 100 - i,
          }));
      const contents: Record<number, string> = { 2: "한국어를 공부해요." };
      (window as any).libraryCalls = [];
      (window as any).failNextSave = false;
      (window as any).sori = {
        invoke: async (channel: string, command: string, payload: any) => {
          if (channel === "dialog:openDocument") return "/sample.pdf";
          if (channel === "dialog:openVideo") return "/sample.mkv";
          (window as any).libraryCalls.push({ command, payload });
          if (command === "library:state")
            return {
              ok: true,
              data: { documents, videos, vocabulary: [], youtubeHistory: [], error: "" },
              error: "",
            };
          if (command === "document:read")
            return {
              ok: true,
              data: { content: contents[payload.id] || "", position: 0, pdfPath: null },
              error: "",
            };
          if ((window as any).failNextSave && command === "document:add") {
            (window as any).failNextSave = false;
            return { ok: false, data: null, error: "Could not save text. Try again." };
          }
          if (command === "document:add") {
            const id = 10;
            documents.push({ id, title: payload.title || "Pasted text", pdf: false });
            contents[id] = payload.content;
          }
          if (command === "document:update") {
            documents = documents.map((item) =>
              item.id === payload.id ? { ...item, title: payload.title } : item,
            );
            contents[payload.id] = payload.content;
          }
          if (command === "document:remove")
            documents = documents.filter((item) => item.id !== payload.id);
          if (command === "video:remove") videos = videos.filter((item) => item.id !== payload.id);
          if (command === "document:import")
            documents.push({ id: 11, title: "Imported PDF", pdf: true });
          if (command === "video:import")
            videos.push({
              id: 12,
              title: "Imported video",
              displayTitle: "Imported video",
              seconds: 0,
              duration: 0,
              thumbnailUrl: null,
              watchedAt: 0,
            });
          if (command === "video:thumbnail") return { ok: false, data: null, error: "No thumbnail" };
          return { ok: true, data: null, error: "" };
        },
        onEvent: () => () => {},
      };
    },
    { empty },
  );
}

async function actions(page: Page, title: string) {
  const button = page.getByRole("button", { name: `Actions for ${title}`, exact: true });
  await button.focus();
  await button.click();
}

test("library renders portrait covers, video progress and searches display and original titles", async ({
  page,
}) => {
  await seed(page);
  await page.goto("/#/library");
  await expect(page.locator(".document-shelf .media-card")).toHaveCount(2);
  await expect(page.locator(".type-badge")).toHaveText(["PDF", "TEXT"]);
  await expect(page.locator(".video-shelf .media-card")).toHaveCount(3);
  await expect(page.locator(".metadata").first()).toHaveText("5:48 / 1:04:33");
  await page.getByRole("textbox", { name: "Search your library" }).fill("1080p");
  await expect(page.locator(".video-shelf .media-card")).toHaveCount(3);
  await expect(page.locator(".document-shelf")).toHaveCount(0);
  await page.getByRole("textbox", { name: "Search your library" }).fill("nothing matches");
  await expect(page.getByRole("status")).toContainText("No matching items");
});

test("paste, edit, save errors, cancel and delete work through item menus", async ({ page }) => {
  await seed(page);
  await page.goto("/#/library");
  await page.getByTestId("import-text").click();
  await page.getByRole("textbox", { name: "Title", exact: true }).fill("New text");
  await page.getByRole("textbox", { name: "Text", exact: true }).fill("안녕하세요");
  await page.evaluate(() => {
    (window as any).failNextSave = true;
  });
  await page.getByTestId("save-document").click();
  await expect(page.getByRole("alert")).toContainText("Could not save");
  await expect(page.getByRole("textbox", { name: "Text", exact: true })).toHaveValue("안녕하세요");
  await page.getByTestId("save-document").click();
  await expect(page.getByTestId("open-document-10")).toBeVisible();
  await actions(page, "New text");
  await page.getByRole("menuitem", { name: "Edit", exact: true }).click();
  await page.getByRole("textbox", { name: "Title", exact: true }).fill("Edited text");
  await page.getByTestId("save-document").click();
  await expect(page.getByTestId("open-document-10")).toContainText("Edited text");
  await actions(page, "Edited text");
  await page.getByRole("menuitem", { name: "Delete", exact: true }).click();
  await page.getByRole("button", { name: "Cancel", exact: true }).click();
  await expect(page.getByTestId("open-document-10")).toBeVisible();
  await actions(page, "Edited text");
  await page.getByRole("menuitem", { name: "Delete", exact: true }).click();
  await page.getByRole("button", { name: "Delete", exact: true }).click();
  await expect(page.getByTestId("open-document-10")).toHaveCount(0);
  await expect(page.getByRole("textbox", { name: "Search your library" })).toBeFocused();
});

test("PDF and video imports remain available and PDFs cannot enter the text editor", async ({
  page,
}) => {
  await seed(page);
  await page.goto("/#/library");
  await page.getByTestId("import-text").click();
  await page.getByTestId("choose-file").click();
  await expect(page.getByTestId("open-document-11")).toBeVisible();
  await actions(page, "Imported PDF");
  await expect(page.getByRole("menuitem", { name: "Edit", exact: true })).toHaveCount(0);
  await page.keyboard.press("Escape");
  await page.getByTestId("import-video").click();
  await expect(page.getByTestId("open-video-12")).toBeVisible();
  await actions(page, "Imported video");
  await page.getByRole("menuitem", { name: "Remove", exact: true }).click();
  await expect(page.getByRole("dialog")).toContainText("video file stays on disk");
  await page.getByRole("button", { name: "Remove", exact: true }).click();
  await expect(page.getByTestId("open-video-12")).toHaveCount(0);
  await expect(page.getByTestId("open-document-1")).toHaveAttribute("href", "#/reader?id=1");
  await expect(page.getByTestId("open-video-3")).toHaveAttribute("href", "#/watch?id=3");
});

test("empty shelves have useful import controls", async ({ page }) => {
  await seed(page, true);
  await page.goto("/#/library");
  await expect(page.getByTestId("empty-texts")).toHaveText("No texts yet");
  await page.getByTestId("import-text").click();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("textbox", { name: "Search your library" })).toBeFocused();
});

test("Library visual baselines fit desktop, dark theme, hover and narrow windows", async ({ page }) => {
  await seed(page);
  await page.setViewportSize({ width: 1908, height: 1030 });
  await page.goto("/#/library");
  await expect(page.getByTestId("open-document-2")).toBeVisible();
  await page.getByTestId("open-document-2").hover();
  await page.screenshot({ path: "test-results/library-baseline/light.png", animations: "disabled" });
  await page.getByRole("button", { name: "Appearance", exact: true }).click();
  await page.getByTestId("theme-dark").click();
  await page.keyboard.press("Escape");
  await expect(page.locator('[data-slot="sheet-content"]')).toHaveCount(0);
  await page.screenshot({ path: "test-results/library-baseline/dark.png", animations: "disabled" });
  await page.setViewportSize({ width: 640, height: 720 });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({ path: "test-results/library-baseline/mobile.png", animations: "disabled" });
});

test("decomposed Hangul is composed for display and search without rewriting stored titles", async ({
  page,
}) => {
  await seed(page);
  await page.goto("/#/library");
  const title = page.getByTestId("open-document-1").locator("h3");
  await expect(title).toHaveText("Ep. 162 한국인은 다 아는 무서운 이야기-1");
  await expect(title).toHaveCSS("font-family", /Noto Sans KR/);
  await page.getByRole("textbox", { name: "Search your library" }).fill("한국인");
  await expect(page.getByTestId("open-document-1")).toBeVisible();
  await page.getByRole("textbox", { name: "Search your library" }).fill("한국인".normalize("NFD"));
  await expect(page.getByTestId("open-document-1")).toBeVisible();
  await expect
    .poll(() =>
      page.evaluate(
        () =>
          (window as any).libraryCalls.filter((call: any) => call.command === "document:update").length,
      ),
    )
    .toBe(0);
});

test("import dialog matches the file-first editor and restores focus on Cancel", async ({ page }) => {
  await seed(page);
  await page.goto("/#/library");
  await page.getByTestId("import-text").click();
  const dialog = page.getByRole("dialog", { name: "Import text or PDF", exact: true });
  await expect(dialog).toBeVisible();
  await expect(page.getByRole("textbox", { name: "Title", exact: true })).toBeFocused();
  await expect(page.getByTestId("save-document")).toBeDisabled();
  await expect(page.getByTestId("choose-file")).toHaveText("Choose a text or PDF file");
  await page.screenshot({
    path: "test-results/library-baseline/import-dialog.png",
    animations: "disabled",
  });
  await page.getByRole("button", { name: "Cancel", exact: true }).click();
  await expect(dialog).not.toBeVisible();
  await expect(page.getByRole("textbox", { name: "Search your library" })).toBeFocused();
});
