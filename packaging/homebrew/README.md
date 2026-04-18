Homebrew packaging notes for Hermes Agent.

Use `packaging/homebrew/hermes-agent.rb` as a tap or `homebrew-core` starting point.

Key choices:
- Stable builds currently target the GitHub release tag tarball and set an explicit semver `version`, because releases do not yet attach a semver-named sdist asset.
- `faster-whisper` now lives in the `voice` extra, which keeps wheel-only transitive dependencies out of the base Homebrew formula.
- The formula no longer uses a separate brewed `cryptography` dependency; Python crypto deps are handled through generated package resources.
- The wrapper exports `HERMES_BUNDLED_SKILLS`, `HERMES_OPTIONAL_SKILLS`, and `HERMES_MANAGED=homebrew` so packaged installs keep runtime assets and defer upgrades to Homebrew.

Typical update flow:
1. Bump the formula `url`, `version`, and `sha256`.
2. Refresh Python resources with `brew update-python-resources --print-only hermes-agent`.
3. Keep `exclude_packages: %w[certifi pydantic]`.
4. Verify `brew audit --new --strict hermes-agent` and `brew test hermes-agent`.
