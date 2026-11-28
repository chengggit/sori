import { expect, test } from "@playwright/test";
function pdfFixture() {
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [4 0 R 6 0 R 8 0 R] /Count 3 >>",
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
  ];
  for (let i = 0; i < 3; i++) {
    objects.push(
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents ${5 + i * 2} 0 R >>`,
    );
    const text = `BT /F1 20 Tf 72 700 Td (PDF sample page ${i + 1}) Tj ET`;
    objects.push(`<< /Length ${text.length} >>\nstream\n${text}\nendstream`);
  }
  let result = "%PDF-1.4\n";
  const offsets = [0];
  objects.forEach((object, i) => {
    offsets.push(Buffer.byteLength(result));
    result += `${i + 1} 0 obj\n${object}\nendobj\n`;
  });
  const xref = Buffer.byteLength(result);
  result += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  result += offsets
    .slice(1)
    .map((offset) => `${String(offset).padStart(10, "0")} 00000 n \n`)
    .join("");
  return Buffer.from(
    result + `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`,
  );
}

test("text reader uses its document title, plain column and preserved progress", async ({ page }) => {
  await page.addInitScript(() => {
    (window as any).saves = [];
    (window as any).sori = {
      onEvent: () => () => {},
      invoke: async (_channel: string, command: string, payload: any) => {
        let data: any = null;
        if (command === "library:state")
          data = {
            documents: [
              { id: 1, title: "KAIST" },
              { id: 2, title: "Second" },
            ],
          };
        if (command === "document:read")
          data = {
            content: payload.id === 1 ? "한국 연구진 개발 성공\n\n".repeat(80) : "두번째 문서",
            pdfPath: null,
            position: payload.id === 1 ? 0.6 : 0,
          };
        if (command === "analyzeText")
          data = [{ form: "한국", tag: "NNG", start: 0, end: 2, surface: "한국" }];
        if (command === "progress:saveDocument") (window as any).saves.push(payload);
        if (command === "dictionary:settings") data = { provider: "wiktionary" };
        if (command === "dictionary:lookup") data = [];
        return { ok: true, data, error: "" };
      },
    };
  });
  await page.setViewportSize({ width: 1908, height: 1030 });
  await page.goto("/#/reader?id=1");
  await expect(page.getByText("KAIST", { exact: true })).toBeVisible();
  const reader = page.getByTestId("reader-text");
  await expect
    .poll(() => reader.evaluate((el) => el.scrollTop / (el.scrollHeight - el.clientHeight)))
    .toBeCloseTo(0.6, 1);
  expect(await reader.locator("article").evaluate((el) => el.clientWidth)).toBeLessThanOrEqual(780);
  await reader.evaluate((el) => {
    el.scrollTop = 0;
  });
  await expect(page.getByTestId("token-0")).toBeVisible();
  await page.getByTestId("token-0").click();
  await expect(page.getByTestId("reader-analysis")).toBeVisible();
  await page.getByRole("button", { name: "Close analysis", exact: true }).click();
  await expect(page.getByTestId("reader-analysis")).toHaveCount(0);
  await page.screenshot({ path: "test-results/reader-baseline/text.png" });
  await page.evaluate(() => {
    location.hash = "/reader?id=2";
  });
  await expect(page.getByText("Second", { exact: true })).toBeVisible();
  await expect(reader).toContainText("두번째 문서");
  await expect(page.getByTestId("reader-analysis")).toHaveCount(0);
  await expect
    .poll(() =>
      page.evaluate(() =>
        (window as any).saves.some((item: any) => item.id === 1 && item.position === 0),
      ),
    )
    .toBe(true);
});

test("PDF fits Book view and preserves its page across zoom, Scroll and resize", async ({ page }) => {
  const fixture = pdfFixture();
  await page.route("**/reader-fixture.pdf", (route) =>
    route.fulfill({ contentType: "application/pdf", body: fixture }),
  );
  await page.addInitScript(() => {
    const open = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function (method: string, url: string | URL, ...args: any[]) {
      return (open as any).call(
        this,
        method,
        String(url).startsWith("sori-pdf:") ? "/reader-fixture.pdf" : url,
        ...args,
      );
    };
    (window as any).sori = {
      onEvent: () => () => {},
      invoke: async (_channel: string, command: string) => ({
        ok: true,
        error: "",
        data:
          command === "document:read"
            ? { content: "", pdfPath: "sample.pdf", position: 0 }
            : command === "library:state"
              ? { documents: [{ id: 1, title: "PDF sample" }] }
              : null,
      }),
    };
  });
  await page.setViewportSize({ width: 1908, height: 1030 });
  await page.goto("/#/reader?id=1");
  const canvas = page.getByTestId("pdf-container").locator("canvas").first();
  await expect(canvas).toBeVisible();
  await expect(page.locator(".textLayer span").first()).toBeVisible();
  await page.getByRole("button", { name: "Next page", exact: true }).click();
  await expect(page.getByTestId("pdf-page")).toHaveText("Page 2 / 3");
  const box = (await canvas.boundingBox())!;
  expect(box.y + box.height).toBeLessThanOrEqual(1030);
  await page.getByRole("button", { name: "Zoom in", exact: true }).click();
  await expect(page.getByRole("button", { name: "Reset PDF zoom" })).toHaveText("110%");
  await page.getByRole("button", { name: "Reset PDF zoom" }).click();
  await page.screenshot({ path: "test-results/reader-baseline/book.png" });
  await page.getByRole("button", { name: "Scroll", exact: true }).click();
  await expect(page.getByRole("button", { name: "Book", exact: true })).toBeVisible();
  await expect.poll(async () => (await canvas.boundingBox())?.width).toBe(920);
  await page.screenshot({ path: "test-results/reader-baseline/scroll.png" });
  await page.setViewportSize({ width: 900, height: 700 });
  await expect.poll(async () => (await canvas.boundingBox())?.width ?? 1000).toBeLessThan(700);
  await page.getByRole("button", { name: "Book", exact: true }).click();
  await expect(page.getByTestId("pdf-page")).toHaveText("Page 2 / 3");
  await expect(page.getByTestId("pdf-error")).toHaveCount(0);
});
