# Test Data File Notes

These files are used to test upload behavior and edge cases.

## File List

- `wall-e.png` (4.0MB) - standard image file
- `test-red-image.png` (334B) - tiny file test
- `      .png` (4.0MB) - blank filename (spaces only)
- `test invalid filename %$~[] `$id`.png` (4.0MB) - special character filename
- `unicode-multilingual.pdf` (459KB) - Unicode/multilingual filename, non-image file
- `big file  OCPP-2.0.1_part2_specification_edition2.pdf` (13MB) - oversized non-image file

## Usage Example

See upload tests under `test/vmemo_web`.
