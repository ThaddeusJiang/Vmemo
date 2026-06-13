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
  url: string;
  status: number;
  durationMs: number;
  contentLength: number | null;
  contentType: string | null;
  server: string | null;
};

const pageReadyBudgetMs = readNumberEnv("PHOTOS_INDEX_READY_BUDGET_MS", 3_000);
const imageResponseBudgetMs = readNumberEnv("STORAGE_IMAGE_RESPONSE_BUDGET_MS", 1_500);
const minExpectedImages = readNumberEnv("PHOTOS_INDEX_MIN_IMAGES", 1);

test("photos index image display performance", async ({ page }, testInfo) => {
  const storageResponses: ResponseMetric[] = [];
  const storageRequestStartMs = new Map<Request, number>();

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

  const firstImage = page.locator("#waterfall-images img").first();
  await expect(firstImage).toBeVisible({ timeout: 20_000 });
  await expect
    .poll(() =>
      firstImage.evaluate(
        (image) => (image as HTMLImageElement).complete && (image as HTMLImageElement).naturalWidth > 0,
      ),
    )
    .toBe(true);

  const firstImageReadyMs = Date.now() - startMs;
  const browserImages = await collectBrowserImageMetrics(page);
  const loadedImages = browserImages.filter((image) => image.complete && image.naturalWidth > 0);
  const report = buildReport(firstImageReadyMs, browserImages, storageResponses);

  console.log(JSON.stringify(report, null, 2));

  await testInfo.attach("photos-index-image-performance.json", {
    body: JSON.stringify(report, null, 2),
    contentType: "application/json",
  });

  expect(loadedImages.length).toBeGreaterThanOrEqual(minExpectedImages);
  expect(storageResponses.length).toBeGreaterThanOrEqual(minExpectedImages);
  expect(storageResponses.map((response) => response.status)).toEqual(
    expect.arrayContaining([200]),
  );
  expect(storageResponses.every((response) => response.status < 400)).toBe(true);
  expect(firstImageReadyMs).toBeLessThanOrEqual(pageReadyBudgetMs);
  expect(maxDuration(storageResponses)).toBeLessThanOrEqual(imageResponseBudgetMs);
});

async function collectBrowserImageMetrics(page: import("@playwright/test").Page) {
  return page.locator("#waterfall-images img").evaluateAll((images) =>
    images.map((image) => {
      const htmlImage = image as HTMLImageElement;
      const entry = performance
        .getEntriesByName(htmlImage.currentSrc)
        .at(-1) as PerformanceResourceTiming | undefined;

      return {
        url: new URL(htmlImage.currentSrc).pathname,
        naturalWidth: htmlImage.naturalWidth,
        naturalHeight: htmlImage.naturalHeight,
        complete: htmlImage.complete,
        durationMs: Math.round(entry?.duration ?? 0),
        transferSize: entry?.transferSize ?? 0,
        encodedBodySize: entry?.encodedBodySize ?? 0,
        decodedBodySize: entry?.decodedBodySize ?? 0,
      } satisfies BrowserImageMetric;
    }),
  );
}

function buildReport(
  firstImageReadyMs: number,
  browserImages: BrowserImageMetric[],
  storageResponses: ResponseMetric[],
) {
  const totalEncodedBytes = browserImages.reduce(
    (sum, image) => sum + image.encodedBodySize,
    0,
  );

  return {
    budgets: {
      pageReadyBudgetMs,
      imageResponseBudgetMs,
      minExpectedImages,
    },
    summary: {
      firstImageReadyMs,
      imageCount: browserImages.length,
      storageRequestCount: storageResponses.length,
      maxBrowserImageDurationMs: maxDuration(browserImages),
      maxStorageResponseDurationMs: maxDuration(storageResponses),
      totalEncodedBytes,
    },
    browserImages,
    storageResponses,
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
