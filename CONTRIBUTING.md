We love contributions, and anyone is welcome. Documentation updates, bugfixes, and new feature requests are all appreciated.

# Contributing Code

## Basic Procedure

- Write your code, following general good coding practice as well as the rules below.
- **Write migrations** if your code breaks saves. "Breaking saves" is more subtle than you think; Cybersyn state is quite complex. Code that breaks saves without a migration will not be accepted.
- **Write docs** if your code changes a user-visible feature. English docs are in `site/docs` in Markdown format with Docusaurus extensions. First comment on PRS not having docs will be to add docs.
- Submit a PR.
- **Join Discord and discuss your PR with your fellow contributors.** It helps if the PR is up on the repo first so we can look at the code. Any PR that changes anything non-obvious will need at least some discussion.

## Coding Standards and Quirks

### Linting and Formatting

Linting is done via a combination of the `LuaLS` built-in linter, as well as `selene`. Submitted code must lint cleanly.

Auto-formatting is done by `stylua`. Submitted code must be auto-formatted. VSCode users can use the `stylua` plugin and Format-on-Save.

### Lua Coding Rules

Due to some quirks in the way LuaLS and FMTK work, there are a few coding rules to follow so that all our editors work nicely.

#### Use of Globals

- Each mod has a unique global table, `_G.cs2` for CS2, `_G.mgr` for the manager. All global data must go in those tables, never in `_G`.

- When writing to these global tables, always do so in a fully-qualified fashion, i.e. `_G.cs2.x.y = ...`. Assigning via indirection from a local confuses LuaLS/FMTK and your global function won't have appropriate code completion.
