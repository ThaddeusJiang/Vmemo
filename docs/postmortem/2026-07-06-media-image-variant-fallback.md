# Media Image Variant Fallback

## What happened

- Commit `810d2efe` changed browser image rendering to fixed media routes such as `/media/images/:id/thumb` and `/media/images/:id/detail`.
- Images uploaded before that change often did not have the new `.thumb.webp` and `.detail.webp` files.
- Those media routes returned `404`, so already-uploaded images could no longer display in thumbnail and detail surfaces.

## Root cause

- The fixed media route only served the requested pre-generated variant file.
- The implementation and tests treated a missing `thumb` or `detail` variant as a hard missing file instead of a legacy-data fallback case.
- `mix storage.warm_images` could generate missing variants, but display availability incorrectly depended on that separate maintenance step.

## Fix applied

- `VmemoWeb.FileController.show_image_variant/2` now prefers the requested generated variant and falls back to the original image file when `thumb` or `detail` is missing.
- The fallback enqueues an AshOban thumbnail-generation job so future requests can use the fixed variants, but it does not synchronously generate image variants during the response path.
- Controller tests now cover missing `thumb` and `detail` variants for historical images.
- The upload images feature spec now states that missing display variants fall back to the original image and enqueue async generation, while `mix storage.warm_images` remains the batch warmup path.

## What we learned

- Media route migrations need a display-safe path for existing storage data.
- Warmup tasks are useful for performance, but they should not be required for basic image availability after deploy.
- Regression tests should include legacy records that have only the original storage file.
- Fallbacks should be self-healing when the missing derivative can be rebuilt safely in the background.
