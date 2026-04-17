# Precompiled Platform Gems for zvec-ruby

**Date:** 2026-04-17
**Status:** Design approved, pending implementation plan

## Problem

`zvec-ruby` releases currently publish only the source (`ruby` platform) gem. Installing on a server requires a C++ toolchain, CMake, and manually building the upstream zvec C++ library plus its thirdparty dependencies (arrow, rocksdb, protobuf, etc.). This build is slow, fragile, and fails on lean production servers. The README advertises precompiled Linux gems that do not actually exist on RubyGems.

## Goal

Ship platform-specific precompiled gems for each release so that `gem install zvec-ruby` on a matching server downloads a ready-to-load native bundle with no build step. Keep the source gem as a fallback for unmatched platforms.

## Decisions

- **Target platforms (4):** `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `arm64-darwin`.
- **Build environment:** GitHub Actions on tag push, matrix of 4 parallel jobs on `ubuntu-latest`, each using `rake-compiler-dock`.
- **Zvec pinning:** Pin upstream zvec to a specific commit SHA in `Rakefile` (`ZVEC_REF`). Bumped manually when a newer zvec is desired.
- **Publishing target:** rubygems.org only via CI. gem.coop continues to be pushed manually using the command in the project's local `CLAUDE.md`.

## Architecture

```
git tag v0.2.1 → push
        │
        ▼
.github/workflows/release.yml

  build-native (matrix, 4 parallel, ubuntu-latest):
    x86_64-linux, aarch64-linux, x86_64-darwin, arm64-darwin
    each job:
      - checkout
      - setup ruby 3.3
      - bundle install
      - bundle exec rake gem:precompile:<platform>
          (inside rake-compiler-dock container:
            git clone zvec @ ZVEC_REF
            cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
            make -j && make install
            rake native:<platform> gem RUBY_CC_VERSION=3.1.0:3.2.0:3.3.0:3.4.0)
      - upload pkg/zvec-ruby-<v>-<platform>.gem as artifact

  build-source (ubuntu-latest):
    - gem build zvec.gemspec
    - upload zvec-ruby-<v>.gem as artifact

  publish (needs: build-native, build-source):
    - download all 5 artifacts into pkg/
    - gem push pkg/*.gem (GEM_HOST_API_KEY from RUBYGEMS_API_KEY secret)
    - create GitHub Release attaching all 5 gems
```

Five gems total per release: 4 platform + 1 source. Bundler selects the matching platform automatically on install.

## Components

### Rakefile changes

1. Add constants at top:
   ```ruby
   ZVEC_REPO = "https://github.com/alibaba/zvec"
   ZVEC_REF  = "<pinned-commit-sha>"  # bumped manually
   ```
2. Replace the current aggregate `gem:precompile` task with `gem:precompile:<platform>`, one per platform in `CROSS_PLATFORMS`. Keep a top-level `gem:precompile` task that invokes all four as a local convenience.
3. Inside each per-platform task, the container script uses `git clone $ZVEC_REPO /tmp/zvec && git -C /tmp/zvec checkout $ZVEC_REF` instead of `--depth 1`.
4. Keep the existing `cross_compiling` hook unchanged — it already strips `ext/` and the `rice` dev dependency from platform gems (correct for prebuilt bundles).

No changes required to `zvec.gemspec` or `ext/zvec/extconf.rb`.

### GitHub Actions workflow

New file: `.github/workflows/release.yml`.

- **Trigger:** `on: push: tags: ['v*']`.
- **Jobs:** `build-native` (matrix), `build-source`, `publish` (with `needs: [build-native, build-source]`).
- **Secret:** `RUBYGEMS_API_KEY` (added to repo settings before first release) → passed as `GEM_HOST_API_KEY` env var to `gem push`.
- **Docker:** `ubuntu-latest` runners include Docker; no extra setup for `rake-compiler-dock`.

## Release Process (human steps)

Per release:
1. Bump `Zvec::VERSION` in `lib/zvec/version.rb`.
2. Update `CHANGELOG.md`.
3. If moving to a newer upstream zvec, bump `ZVEC_REF` in `Rakefile`.
4. Commit; `git tag vX.Y.Z && git push --tags`.
5. CI runs (~30–40 min for 4 parallel Docker builds).
6. On success: rubygems.org has the new version + 4 platform variants; GitHub Release contains the `.gem` files.
7. **Manual:** push to gem.coop using the command already in the project's local `CLAUDE.md`.

## Verification

Before the first production release:
1. **Local dry-run:** run `bundle exec rake gem:precompile:x86_64-linux` on the maintainer laptop to validate the updated Rakefile end-to-end for one platform (fastest signal).
2. **Trial release on a pre-release tag:** tag `v0.2.1.pre1`, let CI run, inspect artifacts without the `publish` job pushing to production (either via `workflow_dispatch` flag guarding the publish step on first run, or by manual review of artifacts before merging a `publish-enable` flip).
3. **Install test on the actual server:** `gem install zvec-ruby --platform x86_64-linux` on the target Linux server; confirm `require "zvec"` succeeds without a build step.

## Risks

- **Darwin cross-compile from Linux may fail** for parts of the zvec thirdparty stack (arrow, rocksdb). If so, fall back to building only the two Linux platform gems in CI and keeping Darwin as a local build. Decision made after step 1 of verification.
- **Gem size.** Statically linking zvec + arrow + rocksdb may exceed the rubygems.org default 100 MB gem size limit. Mitigations: strip symbols (`strip --strip-unneeded`) in the Rakefile before packaging, or request a size limit increase from RubyGems support.
- **`ZVEC_REF` bumps are manual by design.** Document this in `CHANGELOG.md` and in a short section of `README.md` so future releases don't silently drift.

## Addendum: actual starting state (discovered 2026-04-17)

The repo already contains most of the scaffolding assumed by this design. Two adjustments to the design, based on what's in tree:

1. **Darwin builds use native macOS runners** (`macos-13` for x86_64-darwin, `macos-14` for arm64-darwin) in the existing `.github/workflows/precompile.yml`, not `rake-compiler-dock` cross-compile from Linux. This sidesteps the "Darwin cross-compile risk" entirely and is kept.

2. **Darwin gems are single-Ruby.** `script/package_native_gem.rb` bakes the runner's Ruby minor version (3.3) into the gem path, so Darwin platform gems only load under Ruby 3.3. Accepted for now; documented in `README.md`. Linux gems remain fat (3.1–3.4) via `rake-compiler-dock`. Revisit if Darwin users report breakage.

Implementation work is the delta from the current workflow to the design goals: pin `ZVEC_REF`, fix silent `gem push` failures, document the Darwin Ruby-version constraint, and verify end-to-end before first tagged release.

## Out of scope

- Windows platform gem (`x64-mingw-ucrt`). Not currently needed.
- Automated gem.coop publishing (remains manual per decision above).
- Caching the built zvec artifact across CI runs (possible follow-up; not blocking first release).
