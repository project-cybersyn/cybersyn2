We love contributions, and anyone is welcome. Documentation updates, bugfixes, and new feature requests are all appreciated.

# Contributing Code

## Basic Procedure

- Be aware of our AI policy (See below)
- Write your code, following general good coding practice as well as the rules below.
- **Write migrations** if your code breaks saves. "Breaking saves" is more subtle than you think; Cybersyn state is quite complex. Code that breaks saves without a migration will not be accepted.
- **Write docs** if your code changes a user-visible feature. English docs are in `site/docs` in Markdown format with Docusaurus extensions. First comment on PRS not having docs will be to add docs.
- Submit a PR.
- **Join Discord and discuss your PR with your fellow contributors.** It helps if the PR is up on the repo first so we can look at the code. Any PR that changes anything non-obvious will need at least some discussion.

## AI Policy

- It is okay to use AI to help you write code, however **all submitted code must be vetted, understood, and maintained by the person submitting it.**
- If you are not willing, as a person, to be responsible for the code you submit (for example, if you don't know how to code yourself) then do not submit code.
- AI-generated documentation updates are okay, **as long as a human has checked the output and it makes sense.**

## Coding Standards and Quirks

### Linting and Formatting

Submitted code must lint cleanly via EmmyLua and be free of type errors.

Auto-formatting is done by `stylua`. Submitted code must be auto-formatted. VSCode users can use the `stylua` plugin and Format-on-Save.

