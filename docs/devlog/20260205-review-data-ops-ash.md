---
title: Review data operations vs Ash resources
date: 2026-02-05
---

## Goal
- Review current data operation paths and identify non-Ash access.
- Assess whether `TsNote`/`TsPhoto` still make sense or should be consolidated with Ash.

## Notes
- Focused on Typesense access paths in `Vmemo.PhotoService.TsPhoto` and `Vmemo.PhotoService.TsNote`.
- Checked Ash resources for photos/notes and background sync workers.
- Updated search-by-photo upload to use `Photo.create_with_sync` instead of direct Typesense writes.
- Switched home page photo count to Ash-based count.
- Photos index now reuses `Photo.hybrid_search` and `Photo.hybrid_search_count` for search results and counts.

## Next
- Provide review findings and consolidation options.
