# Contributing to QUVIAI Render (SketchUp Extension)

Thank you for your interest in contributing!

## Requirements

- SketchUp 2021 or newer (Ruby 2.7+ embedded)
- A [QUVIAI account](https://quvi.ai) for manual testing

## How to Contribute

1. **Fork** this repository
2. **Create a branch** from `main`: `git checkout -b feature/your-feature`
3. **Make your changes**
4. **Open a Pull Request** against `main`

All PRs are reviewed by the maintainer. Please do not merge your own PRs.

## Development Setup

```bash
git clone https://github.com/quvi-ai/sketchup-plugin
cd sketchup-plugin
```

Install the extension in SketchUp for development:

1. Build the `.rbz` package:
   ```bash
   bash scripts/build_rbz.sh
   ```
2. In SketchUp: **Window → Extension Manager → Install Extension…**
3. Select the generated `quviai_sketchup.rbz`

During development you can also symlink or copy `quviai_sketchup/` and `quviai_sketchup.rb` directly into your SketchUp plugins folder (path varies by OS).

## Building the RBZ Package

```bash
bash scripts/build_rbz.sh
# Output: quviai_sketchup.rbz
```

The script zips `quviai_sketchup.rb` and `quviai_sketchup/` into an RBZ (which is a standard ZIP with a `.rbz` extension).

## Extension Warehouse Submission

The RBZ is submitted to the [Trimble Extension Warehouse](https://extensions.sketchup.com/).
Trimble handles code signing automatically during the submission review process — **no manual signing step is required** by contributors.

For security vulnerabilities, report them via [GitHub Security Advisories](../../security/advisories).

## Code Guidelines

- No secrets or API keys anywhere in the codebase
- SketchUp 2021+ compatible (Ruby 2.7+)
- Keep commits atomic and commit messages imperative
- Ruby style: 2-space indent, `freeze` all string constants

## Reporting Bugs

Use [GitHub Issues](../../issues).
For security vulnerabilities, report via [GitHub Security Advisories](../../security/advisories).
