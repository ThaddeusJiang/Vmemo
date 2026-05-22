---
name: "vmemo-coding-guides"
description: "开发时必须遵守 Vmemo 的编码规范与工程约束。"
---

# Vmemo Coding Guides

Use this skill for implementation tasks in this repository.

## Rule Index (split by frameworks/libraries)

- General engineering rules:
  - `references/core-engineering.md`
- Framework rules:
  - `references/framework-ash.md`
  - `references/framework-phoenix-liveview.md`
- Library rules:
  - `references/library-oban.md`

## Must Follow

- Keep backend logic in `lib/vmemo/**` and web-layer logic in `lib/vmemo_web/**`.
- Prefer Ash resource/action/code_interface patterns over ad-hoc alternatives.
- Keep UI copy, code messages, logs, and comments in English.

## Usage

1. Identify current change scope (framework/library involved).
2. Open only the corresponding reference files.
3. Apply the smallest compliant change.
4. If rules conflict, follow framework/library-specific rule first, then general engineering rule.
