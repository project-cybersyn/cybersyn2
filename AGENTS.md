# AGENTS.md

This file provides repository-specific guidance for coding agents working in this
workspace.

## Repository Overview

- Purpose: Cybersyn 2, a Factorio train logistics mod ecosystem.
- Primary code lives in `mods/`.
- Documentation site lives in `site/` (Docusaurus).
- Multiple closely related mods are maintained together (core + plugins/tools).

## Project Areas

### 1) Factorio mods (`mods/`)

- Main mod: `mods/cybersyn2/`
- Related mods/plugins:
  - `mods/cybersyn2-manager/`
  - `mods/cybersyn2-plugin-prod-trains/`
  - `mods/cybersyn2-plugin-space-elevator/`
  - `mods/cybersyn2-save-recovery/`
- Mods are implemented in Lua utilizing the Factorio API.
- Reusable shared Lua library code is in `mods/cybersyn2/lib/core`. New code should try to re-use methods from libraries when appropriate.

When changing mod code:

- Keep save compatibility in mind.
- If a change can break existing saves, add/update migration scripts under the
  affected mod's `migrations/` directory.
- If a change affects user-visible behavior, update docs in `site/docs/`.
- Respect each mod's global table conventions (for example, `_G.cs2`, `_G.mgr`)
  and avoid introducing new top-level globals.

### 2) Documentation site (`site/`)

- Docusaurus app and docs content are under `site/`.
- Source docs are Markdown in `site/docs/`.
- Do not hand-edit generated output in `site/build/`.

## Validation and Quality Checks

Run relevant checks for changed areas before finishing:

### Lua / mod changes

- Format with `stylua` (repo has `stylua.toml`, tabs + 80 columns).
- Typecheck with LuaLS (treat LuaLS diagnostics as the source of truth).
- Keep LuaLS compatibility in mind (avoid patterns that break static analysis
  or completion).

Suggested commands from repo root (if tools are installed):

```powershell
stylua mods
lua-language-server --check mods
```

### Docs/site changes

Run from `site/`:

```powershell
npm install
npm run typecheck
npm run build
```

Use `npm run start` for local interactive docs preview.

## Editing Scope and Safety

- Make focused, minimal changes tied to the request.
- Do not refactor unrelated files in broad sweeps.
- Preserve existing style and file organization.
- Avoid changing licensing/authorship files unless asked.

## Pull Request Readiness

Before considering work complete:

- Code is formatted/typechecked for affected areas.
- Migrations are included when needed for save compatibility.
- Docs are updated for user-visible changes.
- Changelog updates are included when requested by the task.
