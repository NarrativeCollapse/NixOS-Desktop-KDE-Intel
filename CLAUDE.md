# Working on this repo

NixOS 26.05 flake + Home Manager config for the host `shitbox`. See
README.md for layout and usage.

## Before every commit

Run `nix fmt` and `nix flake check`; both must pass with no evaluation
warnings.

## Versioning (keep this up to date)

The config has a version number (`vN`), shown at the top of README.md and in
its Versions table, with a matching git tag.

- Bump the version by one in the same push as any change that affects the
  built system: packages, services, Home Manager config, flake inputs
  (including `nix flake update`).
- Don't bump for docs, comments, or lint config alone.
- For a bump: update "Current version" at the top of README.md, add a row at
  the top of the Versions table (one or two sentences of highlights), and
  after pushing, tag the pushed commit `vN` and push the tag.
- Several commits in one push share one version.
