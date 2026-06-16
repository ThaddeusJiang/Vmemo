# Storage image browser revalidation

## What happened
- Storage images were repeatedly revalidated by the browser and appeared as `304` entries in DevTools even when the image files had not changed.
- This reduced payload bytes, but still kept image requests on every page load.

## Root cause
- The storage controller intentionally used `Cache-Control: public, max-age=0, must-revalidate` for all storage images because image files and generated variants can be rewritten at the same path by actions such as rotation.
- Application-rendered storage URLs did not include a cache-busting version, so the server could not safely mark them as long-lived immutable assets.

## Fix applied
- `Vmemo.Memo.ImageStorage` now appends a `v` query parameter to generated storage image URLs when the source file exists.
- `VmemoWeb.FileController` keeps revalidation for unversioned URLs, but returns `Cache-Control: public, max-age=31536000, immutable` for versioned storage requests.
- Controller and storage tests now cover the versioned URL and cache-control behavior.

## What we learned
- Path-stable files should not be globally marked immutable.
- Browser strong caching is safe when the rendered URL includes a file-derived version and mutable legacy URLs keep revalidation.
