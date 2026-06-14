# Image detail similar search blocked first render

## What happened

Opening an image detail page on staging could appear stuck while the document request remained pending. The main image detail view synchronously loaded visually similar images during LiveView mount, so a slow or unavailable Typesense similar-image request could delay the first HTML response.

## Root cause

`VmemoWeb.ImageIdLive` called `Image.list_similar/3` in the initial mount path before rendering the image detail page. Similar images are secondary content, but the synchronous call made the primary page depend on Typesense availability and response time.

## Fix applied

The image detail LiveView now renders the main image after loading the Postgres image record, then loads similar images asynchronously after the LiveView connects. Similar-image failures are logged and degrade to an empty list. The Typesense request used by `TsImage.list_similar_images/2` also has a short connect and receive timeout.

## What we learned

Primary image detail rendering should only depend on the image record and storage URL. Optional enrichment such as similar images must be async and failure-tolerant, especially on first-render paths that directly affect browser document completion.
