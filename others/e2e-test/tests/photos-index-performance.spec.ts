import { expect, test, type Request } from "@playwright/test";

type BrowserImageMetric = {
  url: string;
  naturalWidth: number;
  naturalHeight: number;
  complete: boolean;
  durationMs: number;
  transferSize: number;
  encodedBodySize: number;
  decodedBodySize: number;
};

type ResponseMetric = {
  phase: "list" | "detail";
  url: string;
  status: number;
  durationMs: number;
  contentLength: number | null;
  contentType: string | null;
  server: string | null;
};

const pageReadyBudgetMs = readNumberEnv("PHOTOS_INDEX_READY_BUDGET_MS", 3_000);
const imageResponseBudgetMs = readNumberEnv("STORAGE_IMAGE_RESPONSE_BUDGET_MS", 1_000);
const minExpectedImages = readNumberEnv("PHOTOS_INDEX_MIN_IMAGES", 1);

test("photos index and detail image display performance", async ({ page }, testInfo) => {
  const storageResponses: ResponseMetric[] = [];
  const storageRequestStartMs = new Map<Request, number>();
  let currentPhase: ResponseMetric["phase"] = "list";

  page.on("request", (request) => {
    if (isStorageImageUrl(request.url())) {
      storageRequestStartMs.set(request, Date.now());
    }
  });

  page.on("response", (response) => {
    const url = response.url();

    if (!isStorageImageUrl(url)) {
      return;
    }

    const request = response.request();
    const headers = response.headers();
    const startedAt = storageRequestStartMs.get(request);
    storageRequestStartMs.delete(request);

    storageResponses.push({
      phase: currentPhase,
      url: new URL(url).pathname,
      status: response.status(),
      durationMs: startedAt ? Date.now() - startedAt : 0,
      contentLength: parseNullableInteger(headers["content-length"]),
      contentType: headers["content-type"] ?? null,
      server: headers.server ?? null,
    });
  });

  const startMs = Date.now();

  await page.goto("/images", { waitUntil: "domcontentloaded" });
  await expect(page.locator("#infinite-scroll")).toHaveCount(1, { timeout: 20_000 });

  const listImages = page.locator("#waterfall-images img");
  await expect(listImages.first()).toBeVisible({ timeout: 20_000 });

  await expect.poll(() => firstLoadedImageIndexOnPage(page), { timeout: 20_000 }).not.toBe(-1);
  const firstLoadedImageIndex = await firstLoadedImageIndexOnPage(page);

  const firstImageReadyMs = Date.now() - startMs;
  const listBrowserImages = await collectBrowserImageMetrics(page, "#waterfall-images img");
  const loadedListImages = listBrowserImages.filter(
    (image) => image.complete && image.naturalWidth > 0,
  );

  currentPhase = "detail";
  const detailStartMs = Date.now();
  await page.locator('#waterfall-images a[href^="/images/"]').nth(firstLoadedImageIndex).click();
  await expect(page).toHaveURL(/\/images\/.+/);

  const detailImage = page.locator("figure.group img").first();
  await expect(detailImage).toBeVisible({ timeout: 20_000 });
  await expect
    .poll(() =>
      detailImage.evaluate(
        (image) =>
          (image as HTMLImageElement).complete &&
          (image as HTMLImageElement).naturalWidth > 0,
      ),
    )
    .toBe(true);

  const detailImageReadyMs = Date.now() - detailStartMs;
  const detailBrowserImages = await collectBrowserImageMetrics(page, 'img[src*="/storage/v1/"]');
  const loadedDetailImages = detailBrowserImages.filter(
    (image) => image.complete && image.naturalWidth > 0,
  );
  const report = buildReport(
    firstImageReadyMs,
    detailImageReadyMs,
    listBrowserImages,
    detailBrowserImages,
    storageResponses,
  );

  console.log(JSON.stringify(report, null, 2));

  await testInfo.attach("photos-index-image-performance.json", {
    body: JSON.stringify(report, null, 2),
    contentType: "application/json",
  });

  const listResponses = storageResponses.filter((response) => response.phase === "list");
  const detailResponses = storageResponses.filter((response) => response.phase === "detail");
  const successfulListResponses = listResponses.filter(isSuccessfulImageResponse);
  const successfulDetailResponses = detailResponses.filter(isSuccessfulImageResponse);

  expect(loadedListImages.length).toBeGreaterThanOrEqual(minExpectedImages);
  expect(loadedDetailImages.length).toBeGreaterThanOrEqual(1);
  expect(successfulListResponses.length).toBeGreaterThanOrEqual(minExpectedImages);
  expect(successfulDetailResponses.length).toBeGreaterThanOrEqual(1);
  expect(firstImageReadyMs).toBeLessThanOrEqual(pageReadyBudgetMs);
  expect(detailImageReadyMs).toBeLessThanOrEqual(pageReadyBudgetMs);
  expect(maxDuration(successfulListResponses)).toBeLessThanOrEqual(imageResponseBudgetMs);
  expect(maxDuration(successfulDetailResponses)).toBeLessThanOrEqual(imageResponseBudgetMs);
});

async function collectBrowserImageMetrics(page: import("@playwright/test").Page, selector: string) {
  return page.locator(selector).evaluateAll((images) =>
    images.flatMap((image) => {
      const htmlImage = image as HTMLImageElement;
      const currentSrc = htmlImage.currentSrc;

      if (!currentSrc) {
        return [];
      }

      const entry = performance
        .getEntriesByName(currentSrc)
        .at(-1) as PerformanceResourceTiming | undefined;

      return [{
        url: new URL(currentSrc, window.location.href).pathname,
        naturalWidth: htmlImage.naturalWidth,
        naturalHeight: htmlImage.naturalHeight,
        complete: htmlImage.complete,
        durationMs: Math.round(entry?.duration ?? 0),
        transferSize: entry?.transferSize ?? 0,
        encodedBodySize: entry?.encodedBodySize ?? 0,
        decodedBodySize: entry?.decodedBodySize ?? 0,
      } satisfies BrowserImageMetric];
    }),
  );
}

async function firstLoadedImageIndexOnPage(page: import("@playwright/test").Page) {
  return page.locator("#waterfall-images img").evaluateAll((images) =>
    images.findIndex((image) => {
      const htmlImage = image as HTMLImageElement;
      return htmlImage.complete && htmlImage.naturalWidth > 0;
    }),
  );
}

function buildReport(
  firstImageReadyMs: number,
  detailImageReadyMs: number,
  listBrowserImages: BrowserImageMetric[],
  detailBrowserImages: BrowserImageMetric[],
  storageResponses: ResponseMetric[],
) {
  const totalEncodedBytes = [...listBrowserImages, ...detailBrowserImages].reduce(
    (sum, image) => sum + image.encodedBodySize,
    0,
  );
  const listResponses = storageResponses.filter((response) => response.phase === "list");
  const detailResponses = storageResponses.filter((response) => response.phase === "detail");
  const failedStorageResponses = storageResponses.filter(
    (response) => !isSuccessfulImageResponse(response),
  );

  return {
    budgets: {
      pageReadyBudgetMs,
      imageResponseBudgetMs,
      minExpectedImages,
    },
    summary: {
      firstImageReadyMs,
      detailImageReadyMs,
      listImageCount: listBrowserImages.length,
      detailImageCount: detailBrowserImages.length,
      storageRequestCount: storageResponses.length,
      maxListBrowserImageDurationMs: maxDuration(listBrowserImages),
      maxDetailBrowserImageDurationMs: maxDuration(detailBrowserImages),
      maxListStorageResponseDurationMs: maxDuration(listResponses.filter(isSuccessfulImageResponse)),
      maxDetailStorageResponseDurationMs: maxDuration(
        detailResponses.filter(isSuccessfulImageResponse),
      ),
      failedStorageResponseCount: failedStorageResponses.length,
      totalEncodedBytes,
    },
    listBrowserImages,
    detailBrowserImages,
    storageResponses,
    failedStorageResponses,
  };
}

function maxDuration(metrics: Array<{ durationMs: number }>) {
  return metrics.reduce((max, metric) => Math.max(max, metric.durationMs), 0);
}

function readNumberEnv(name: string, fallback: number) {
  const value = process.env[name];

  if (!value) {
    return fallback;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function parseNullableInteger(value: string | undefined) {
  if (!value) {
    return null;
  }

  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : null;
}

function isStorageImageUrl(url: string) {
  return url.includes("/storage/v1/") && !url.includes("/storage/v1/_internal/");
}

function isSuccessfulImageResponse(response: ResponseMetric) {
  return response.status >= 200 && response.status < 300 && response.contentType?.startsWith("image/");
}
