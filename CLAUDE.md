# Working on this repo

NixOS 26.05 flake + Home Manager config for the host `shitbox`. See
README.md for layout and usage.

## Before every commit

Run `nix fmt` and `nix flake check`; both must pass with no evaluation
warnings. CI (`.github/workflows/check.yml`) runs the same check plus a full
system build on every push.

## Versioning (keep this up to date)

The config has a version number (`vN`), defined once as `version` in
flake.nix. It becomes a system label tag, and must match the
"**Current version: vN**" line at the top of README.md (`nix flake check`
enforces this). Each version also gets a git tag.

- Bump the version by one in the same push as any change that affects the
  built system: packages, services, Home Manager config, the Brewfile,
  flake inputs. (The weekly `flake.lock` update PR bumps it itself via
  `.github/workflows/bump-version.py`; only tag it after merging.)
- Don't bump for docs, comments, CI, or lint config alone.
- For a bump: change `version` in flake.nix, update "Current version" at the
  top of README.md, add a row at the top of its Versions table (one or two
  sentences of highlights), and after pushing, tag the pushed commit `vN`
  and push the tag.
- Several commits in one push share one version.
