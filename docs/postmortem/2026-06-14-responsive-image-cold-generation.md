# Responsive Image Cold Generation

## What happened

- Some image requests could still take several seconds after moving away from `--s` and `--m` only.
- The browser could request missing responsive variants such as `--640w` or larger candidates, making the request wait for ImageMagick before the image was visible.

## Root cause

- Responsive variants kept the original file extension, so PNG uploads produced PNG derivatives that were larger than necessary for list/detail UI.
- `srcset` exposed all widths to every usage, allowing small UI elements to request oversized derivatives on high-DPR screens.
- Existing storage files had no guaranteed pre-generated responsive variants, so old images could pay cold generation cost during normal browsing.

## Fix applied

- Responsive variants are now generated and served as WebP.
- `srcset` candidates are capped by image usage: thumb, grid, detail, and full.
- Added `Vmemo.Memo.ImageStorage.warm_variants!/1` and `mix storage.warm_images` to pre-generate variants for existing storage files.
- Added a reusable integration performance test for warm list/detail variant requests.

## What we learned

- Responsive image URLs are not enough; candidate width and output format must match the rendered UI.
- Cold image generation should be treated as a maintenance/backfill task, not as a normal browser-visible page-load cost.
- Feed-like image pages should serve small, cacheable derivatives in modern formats, similar to CDN media-variant strategies used by large social feeds.
