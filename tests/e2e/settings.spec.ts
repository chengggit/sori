import { expect, test, type Page } from "@playwright/test";

const errors = new WeakMap<Page, Error[]>();
test.beforeEach(({ page }) => {
  const list: Error[] = [];
  errors.set(page, list);
  page.on("pageerror", (error) => list.push(error));
});
test.afterEach(({ page }) => expect(errors.get(page)).toEqual([]));

async function seed(page: Page, route = "/#/settings", failing = false) {
  await page.addInitScript(
    ({ failing }) => {
      const host = window as any;
      host.settingsCore = { provider: "wiktionary", krdict: false, youtube: false, environment: true };
      host.settingsFail = failing;
      host.settingsMutationFail = false;
      host.settingsSlow = false;
      host.settingsCalls = [];
      let listeners: ((payload: any) => void)[] = [];
      host.sori = {
        onEvent: (_channel: string, fn: (payload: any) => void) => {
          listeners.push(fn);
          return () => (listeners = listeners.filter((x) => x !== fn));
        },
        invoke: async (channel: string, command: any, payload: any) => {
          const name = channel === "core:invoke" ? command : channel;
          const input = channel === "core:invoke" ? payload : command;
          host.settingsCalls.push({ name, input });
          const state = host.settingsCore;
          const fail = (error: string) => ({ ok: false, data: null, error });
          const ok = (data: any = null) => ({ ok: true, data, error: "" });
          if (["dictionary:settings", "youtube:settings"].includes(name) && host.settingsFail)
            return fail("Could not read connection settings.");
          if (name === "dictionary:settings")
            return ok({ provider: state.provider, hasKey: state.krdict });
          if (name === "youtube:settings")
            return ok({ hasKey: state.youtube || state.environment, saved: state.youtube });
          if (/^(dictionary|youtube):(saveKey|removeKey|select)$/.test(name)) {
            if (host.settingsSlow) await new Promise((resolve) => setTimeout(resolve, 500));
            if (host.settingsMutationFail) return fail("Could not save connection settings.");
            if (name === "dictionary:select") {
              if (input.provider === "krdict" && !state.krdict)
                return fail("Save a KRDict API key first.");
              state.provider = input.provider;
            }
            if (name === "dictionary:saveKey") {
              if (!/^[a-f0-9]{32}$/i.test(input.key))
                return fail("KRDict keys must contain 32 hexadecimal characters.");
              state.krdict = true;
            }
            if (name === "dictionary:removeKey") {
              state.krdict = false;
              state.provider = "wiktionary";
            }
            if (name === "youtube:saveKey") state.youtube = true;
            if (name === "youtube:removeKey") state.youtube = false;
            setTimeout(() => listeners.forEach((fn) => fn({ name: "settings-changed" })), 20);
            return ok();
          }
          if (name === "library:state")
            return ok({ documents: [], videos: [], vocabulary: [], youtubeHistory: [], error: "" });
          if (name === "youtube:feed") return ok({ videos: [], nextPageTokens: {} });
          if (name === "youtube:subscriptions") return ok([]);
          return ok();
        },
      };
    },
    { failing },
  );
  await page.goto(route);
}
const category = (page: Page, name: string) =>
  page
    .getByRole("navigation", { name: "Settings categories" })
    .getByRole("button", { name, exact: true });

test("Sidebar Settings opens a dismissible sheet over the current page and restores focus", async ({
  page,
}) => {
  await seed(page, "/#/library");
  await page.getByTestId("nav-settings").click();
  const dialog = page.getByRole("dialog", { name: "Settings", exact: true });
  await expect(dialog).toBeVisible();
  await expect(page).toHaveURL(/#\/library$/);
  await expect(dialog.getByTestId("appearance-settings")).toBeVisible();
  await category(page, "Connections").click();
  await expect(dialog.getByTestId("youtube-key-state")).toHaveText("Using the environment API key.");
  await page.keyboard.press("Escape");
  await expect(dialog).toHaveCount(0);
  await expect(page.getByTestId("nav-settings")).toBeFocused();
  await page.getByTestId("nav-settings").click();
  await expect(dialog.getByTestId("appearance-settings")).toBeVisible();
  await dialog.getByRole("button", { name: "Close", exact: true }).click();
  await expect(dialog).toHaveCount(0);
});

test("General controls persist theme, zoom and reader/transcript typography", async ({ page }) => {
  await seed(page);
  await page.getByTestId("settings-theme-dark").click();
  await expect(page.locator("html")).toHaveClass(/dark/);
  await page.getByRole("combobox", { name: "Reading font" }).selectOption("inter");
  for (const [name, value] of [
    ["Reader text size", "28"],
    ["Reader line height", "64"],
    ["Transcript line height", "48"],
  ]) {
    await page.getByRole("slider", { name, exact: true }).focus();
    await page.keyboard.press("End");
    await expect(page.getByRole("slider", { name, exact: true })).toHaveValue(value);
  }
  await page.getByRole("slider", { name: "Page zoom" }).focus();
  await page.keyboard.press("ArrowRight");
  await expect(page.locator("html")).toHaveCSS("zoom", "1.1");
  await page.reload();
  await expect(page.locator("html")).toHaveClass(/dark/);
  await expect(page.locator("html")).toHaveCSS("zoom", "1.1");
  await expect(page.getByRole("combobox", { name: "Reading font" })).toHaveValue("inter");
  await expect(page.getByRole("slider", { name: "Reader text size", exact: true })).toHaveValue("28");
  await expect(page.getByRole("slider", { name: "Reader line height", exact: true })).toHaveValue("64");
  await expect(page.getByRole("slider", { name: "Transcript line height", exact: true })).toHaveValue(
    "48",
  );
});

test("KRDict selection, validation, replacement and removal show canonical state", async ({ page }) => {
  await seed(page);
  await category(page, "Dictionaries").click();
  const provider = page.getByRole("combobox", { name: "Analysis provider" });
  await provider.selectOption("krdict");
  await expect(page.getByRole("alert")).toHaveText("Save a KRDict API key first.");
  await expect(provider).toHaveValue("wiktionary");
  const key = page.getByLabel("KRDict API key", { exact: true });
  await key.fill("bad");
  await page.getByRole("button", { name: "Save KRDict key", exact: true }).click();
  await expect(page.getByRole("alert")).toContainText("32 hexadecimal");
  await expect(key).toHaveValue("bad");
  await key.fill("0123456789abcdef0123456789abcdef");
  await page.getByRole("button", { name: "Save KRDict key", exact: true }).click();
  await expect(key).toHaveValue("");
  await expect(page.getByText("KRDict key saved locally.", { exact: true })).toBeVisible();
  await provider.selectOption("krdict");
  await expect(provider).toHaveValue("krdict");
  await expect(key).toHaveAttribute("placeholder", "Enter a replacement API key");
  await page.evaluate(() => {
    (window as any).settingsMutationFail = true;
  });
  await page.getByRole("button", { name: "Remove KRDict key", exact: true }).click();
  await expect(page.getByRole("alert")).toContainText("Could not save");
  await expect(provider).toHaveValue("krdict");
  await page.evaluate(() => {
    (window as any).settingsMutationFail = false;
  });
  await page.getByRole("button", { name: "Remove KRDict key", exact: true }).click();
  await expect(provider).toHaveValue("wiktionary");
  await expect(page.getByText("No KRDict key saved.", { exact: true })).toBeVisible();
  await expect(page.getByRole("alert")).toHaveCount(0);
});

test("YouTube keys retain failed drafts, support replacement and restore the environment fallback", async ({
  page,
}) => {
  await seed(page, "/#/library");
  await page.getByTestId("nav-settings").click();
  await category(page, "Connections").click();
  await expect(page.getByTestId("youtube-key-state")).toHaveText("Using the environment API key.");
  const key = page.getByLabel("YouTube API key", { exact: true });
  await key.fill("fake-youtube-key");
  await page.evaluate(() => {
    (window as any).settingsMutationFail = true;
  });
  await page.getByRole("button", { name: "Save YouTube key", exact: true }).click();
  await expect(page.getByRole("alert")).toContainText("Could not save");
  await expect(key).toHaveValue("fake-youtube-key");
  await page.evaluate(() => {
    (window as any).settingsMutationFail = false;
    (window as any).settingsSlow = true;
  });
  await page.getByRole("button", { name: "Save YouTube key", exact: true }).click();
  await expect(page.getByRole("button", { name: "Save YouTube key", exact: true })).toBeDisabled();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("dialog", { name: "Settings", exact: true })).toBeVisible();
  await expect(page.getByTestId("youtube-key-state")).toHaveText("API key saved locally.");
  await expect(key).toHaveValue("");
  await key.fill("replacement-key");
  await page.getByRole("button", { name: "Save YouTube key", exact: true }).click();
  await expect(key).toHaveValue("");
  await page.getByRole("button", { name: "Remove YouTube key", exact: true }).click();
  await expect(page.getByTestId("youtube-key-state")).toHaveText("Using the environment API key.");
  await expect(page.getByRole("button", { name: "Remove YouTube key", exact: true })).toHaveCount(0);
});

test("Embedded dictionaries can be disabled/re-enabled, reordered and custom URLs validated", async ({
  page,
}) => {
  await seed(page);
  await category(page, "Dictionaries").click();
  await page.getByRole("checkbox", { name: "Naver", exact: true }).uncheck();
  await expect(page.getByRole("checkbox", { name: "Naver", exact: true })).not.toBeChecked();
  await page.getByRole("checkbox", { name: "Naver", exact: true }).check();
  await page.getByRole("button", { name: "Move Naver up", exact: true }).click();
  expect(await page.evaluate(() => JSON.parse(localStorage.getItem("sori-embeds")!).enabled)).toEqual([
    "krdict",
    "naver-ko",
    "papago",
  ]);
  const url = page.getByLabel("Custom lookup URL", { exact: true });
  await url.fill("http://example.com/?q={word}");
  await page.getByRole("button", { name: "Add tab", exact: true }).click();
  await expect(page.getByRole("alert")).toContainText("HTTPS address");
  await url.fill("https://example.com/?q={word}");
  await page.getByRole("button", { name: "Add tab", exact: true }).click();
  await expect(page.getByRole("checkbox", { name: "example.com", exact: true })).toBeChecked();
  await url.fill("https://example.com/?q={word}");
  await page.getByRole("button", { name: "Add tab", exact: true }).click();
  await expect(page.getByRole("alert")).toHaveText("That dictionary is already listed.");
  await page.reload();
  await category(page, "Dictionaries").click();
  await expect(page.getByRole("checkbox", { name: "example.com", exact: true })).toBeChecked();
  await page.getByRole("button", { name: "Remove example.com", exact: true }).click();
  await expect(page.getByRole("checkbox", { name: "example.com", exact: true })).toHaveCount(0);
});

test("Settings load failures stay separate from offline preferences and recover per section", async ({
  page,
}) => {
  await seed(page, "/#/settings", true);
  await page.getByTestId("settings-theme-light").click();
  await expect(page.locator("html")).not.toHaveClass(/dark/);
  await category(page, "Dictionaries").click();
  await expect(page.getByRole("alert")).toHaveText("Could not read connection settings.");
  await expect(page.getByLabel("KRDict API key", { exact: true })).toBeDisabled();
  await page.evaluate(() => {
    (window as any).settingsFail = false;
  });
  await page.getByRole("button", { name: "Retry dictionary settings" }).click();
  await expect(page.getByLabel("KRDict API key", { exact: true })).toBeEnabled();
  await category(page, "Connections").click();
  await expect(page.getByRole("alert")).toHaveText("Could not read connection settings.");
  await page.getByRole("button", { name: "Retry YouTube settings" }).click();
  await expect(page.getByTestId("youtube-key-state")).toHaveText("Using the environment API key.");
});

test("Mobile drawer hands Settings focus to the sheet without navigating or losing controls", async ({
  page,
}) => {
  await page.setViewportSize({ width: 600, height: 800 });
  await seed(page, "/#/library");
  await page.getByRole("button", { name: "Toggle Sidebar" }).click();
  await page.getByTestId("nav-settings").click();
  const dialog = page.getByRole("dialog", { name: "Settings", exact: true });
  await expect(dialog).toBeVisible();
  await expect(page).toHaveURL(/#\/library$/);
  await expect(dialog.getByRole("button", { name: "General", exact: true })).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(dialog).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Toggle Sidebar" })).toBeFocused();
});

test("Settings captures General, Dictionaries, Connections, dark, narrow and zoomed layouts", async ({
  page,
}) => {
  await seed(page, "/#/library");
  await page.getByTestId("nav-settings").click();
  await page.screenshot({ path: "test-results/settings-baseline/general.png", animations: "disabled" });
  await category(page, "Dictionaries").click();
  await page.screenshot({
    path: "test-results/settings-baseline/dictionaries.png",
    animations: "disabled",
  });
  await category(page, "Connections").click();
  await page.screenshot({
    path: "test-results/settings-baseline/connections.png",
    animations: "disabled",
  });
  await category(page, "General").click();
  await page.getByTestId("settings-theme-dark").click();
  await page.screenshot({ path: "test-results/settings-baseline/dark.png", animations: "disabled" });
  await page.setViewportSize({ width: 600, height: 720 });
  await page.keyboard.press("Control+Shift+Equal");
  await page.screenshot({
    path: "test-results/settings-baseline/narrow-zoom.png",
    animations: "disabled",
  });
  const dialog = page.getByRole("dialog", { name: "Settings", exact: true });
  await expect(dialog).toBeInViewport();
  const box = (await dialog.boundingBox())!;
  expect(box.y).toBeGreaterThanOrEqual(0);
  expect(box.y + box.height).toBeLessThanOrEqual(721);
  expect(await dialog.evaluate((node) => node.scrollWidth <= node.clientWidth)).toBe(true);
});

test("YouTube key changes refresh the page beneath Settings without navigation", async ({ page }) => {
  await seed(page, "/#/explore");
  const search = page.getByRole("textbox", { name: "Search YouTube", exact: true });
  await expect(search).toBeEnabled();
  await page.getByTestId("nav-settings").click();
  await category(page, "Connections").click();
  await page.getByLabel("YouTube API key", { exact: true }).fill("fake-key");
  await page.getByRole("button", { name: "Save YouTube key", exact: true }).click();
  await expect(page.getByTestId("youtube-key-state")).toHaveText("API key saved locally.");
  await page.evaluate(() => {
    (window as any).settingsCore.environment = false;
  });
  await page.getByRole("button", { name: "Remove YouTube key", exact: true }).click();
  await expect(page.getByTestId("youtube-key-state")).toHaveText("No YouTube API key configured.");
  await page.keyboard.press("Escape");
  await expect(search).toBeDisabled();
  await page.getByTestId("nav-settings").click();
  await category(page, "Connections").click();
  await page.getByLabel("YouTube API key", { exact: true }).fill("fake-key");
  await page.getByRole("button", { name: "Save YouTube key", exact: true }).click();
  await expect(page.getByTestId("youtube-key-state")).toHaveText("API key saved locally.");
  await page.keyboard.press("Escape");
  await expect(search).toBeEnabled();
  await expect(page).toHaveURL(/#\/explore$/);
});
