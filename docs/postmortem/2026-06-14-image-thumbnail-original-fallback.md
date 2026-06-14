# Image Thumbnail Original Fallback

## What happened

- The `/images?q=` grid on the develop deployment loaded some thumbnail URLs as multi-megabyte original images.
- In the sampled first viewport, three `--s.png` URLs each transferred 4,193,042 bytes, and one `--s.JPG` URL returned 404.

## Root cause

- Missing thumbnail paths in `VmemoWeb.FileController` fell back to the original image file.
- Filename normalization lowercased safe filenames before path lookup, so uppercase stored extensions could be resolved to a different path.
- Thumbnail generation wrote directly to final paths, leaving a risk that concurrent reads could observe partially-written files.

## Fix applied

- Added on-demand thumbnail generation for missing `--s` and `--m` requests.
- Made thumbnail writes atomic by generating to a temporary file and renaming into place.
- Preserved filename case while keeping safe-character validation.
- Added controller tests for lazy thumbnail generation and uppercase extension serving.

## What we learned

- Thumbnail URLs must never silently serve original-size files in grid views.
- Image derivative generation should write atomically so web requests cannot read partial files.
- Path safety normalization should validate unsafe characters without changing the storage key.
