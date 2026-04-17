# Precompiled Platform Gems Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship 5 gems per release (4 precompiled platform + 1 source) so that `gem install zvec-ruby` on matching servers requires no C++ toolchain.

**Architecture:** A GitHub Actions workflow (`precompile.yml`, already present) builds native gems on tag push: Linux platforms via `rake-compiler-dock` (fat gem, Ruby 3.1–3.4), Darwin platforms on native macOS runners (single-Ruby, 3.3). A `release` job downloads all artifacts and pushes to rubygems.org. The implementation work is the *delta* from current state to a reliable, pinned, first-release-ready version.

**Tech Stack:** Ruby 3.3, rake-compiler, rake-compiler-dock (Docker), GitHub Actions, CMake, C++17.

**Reference:** `docs/superpowers/specs/2026-04-17-precompiled-platform-gems-design.md`.

---

## Starting state (verified 2026-04-17)

- `.github/workflows/precompile.yml` exists with matrix (linux x2, macos x2), source gem, release job. Uses `--depth 1` zvec clone (unpinned) and `gem push ... || true` (swallows failures).
- `Rakefile` has `Rake::ExtensionTask` with `cross_compile = true` and the 4 `CROSS_PLATFORMS`. A `gem:precompile` rake task exists but is local-only convenience.
- `ext/zvec/extconf.rb` honors `ZVEC_DIR`.
- `script/package_native_gem.rb` packages macOS builds into single-Ruby platform gems.
- `script/build_zvec.sh` clones+builds zvec locally (unpinned).
- No `ZVEC_REF` / zvec pin anywhere.
- No `RUBYGEMS_API_KEY` secret confirmed on the GitHub repo (verify in Task 5).
- Current `Zvec::VERSION` = `0.2.0`.

## File inventory

**Create:**
- `docs/superpowers/plans/2026-04-17-precompiled-platform-gems.md` (this file; already being written)

**Modify:**
- `Rakefile` — add `ZVEC_REPO`/`ZVEC_REF` constants, inline them into `gem:precompile` task script.
- `.github/workflows/precompile.yml` — reference `ZVEC_REF`, fix `gem push` error handling, remove unnecessary retries, add gem-size check.
- `script/build_zvec.sh` — honor `ZVEC_REF` env var (keep current clone logic as fallback).
- `README.md` — document that Darwin precompiled gems require Ruby 3.3; Linux gems cover 3.1–3.4.
- `CHANGELOG.md` — `0.2.1` entry describing the first truly-precompiled release.
- `lib/zvec/version.rb` — bump to `0.2.1` as part of the release task.

**Unchanged (verified correct):**
- `zvec.gemspec`
- `ext/zvec/extconf.rb`
- `script/package_native_gem.rb`

---

## Task 1: Pin zvec in Rakefile

**Why first:** Every subsequent build step depends on a deterministic zvec version. Without the pin, local dry-runs and CI runs cannot be compared.

**Files:**
- Modify: `Rakefile` (top of file, just after the `require` lines)
- Modify: `Rakefile:62-83` (the `gem:precompile` task body)

- [ ] **Step 1: Choose the pinned zvec commit SHA**

Open `https://github.com/alibaba/zvec/commits/main` in a browser. Pick the most recent commit that built cleanly the last time you tested. If you have no prior known-good commit, pick the current `HEAD` of `main`.

Record the full 40-character SHA. Example placeholder in this plan: `ZVEC_SHA_PLACEHOLDER`. Replace with the real SHA in Step 2.

- [ ] **Step 2: Add constants to Rakefile**

Edit `Rakefile`. After the existing `require` lines at the top and before `GEMSPEC = Gem::Specification.load(...)`, insert:

```ruby
# Upstream zvec C++ library — pinned for reproducible builds.
# Bump manually after verifying the new commit builds cleanly across all
# platforms listed in CROSS_PLATFORMS.
ZVEC_REPO = "https://github.com/alibaba/zvec"
ZVEC_REF  = "ZVEC_SHA_PLACEHOLDER"  # <-- replace with the real 40-char SHA
```

- [ ] **Step 3: Thread ZVEC_REF through the precompile task**

Replace the existing `gem:precompile` task body (currently `Rakefile:62-83`) so the in-container script uses `git clone` + `git checkout $ZVEC_REF` instead of `--depth 1`:

```ruby
desc "Build precompiled gems for all platforms using rake-compiler-dock"
task :precompile do
  require "rake_compiler_dock"

  CROSS_PLATFORMS.each do |plat|
    next if plat.include?("darwin")  # Darwin builds on macOS runners in CI, not here

    RakeCompilerDock.sh <<~SCRIPT, platform: plat
      set -e
      git clone #{ZVEC_REPO} /tmp/zvec
      cd /tmp/zvec
      git checkout #{ZVEC_REF}
      mkdir build && cd build
      cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
      make -j$(nproc)
      make install
      ldconfig 2>/dev/null || true

      cd /payload
      export ZVEC_DIR=/tmp/zvec
      bundle install
      rake native:#{plat} gem RUBY_CC_VERSION=#{CROSS_RUBIES.join(':')}
    SCRIPT
  end
end
```

- [ ] **Step 4: Verify Rakefile parses**

Run: `cd /Users/johannesdwicahyo/Projects/2026/ruby-gems/zvec-ruby && bundle exec rake -T | head -20`

Expected: task list prints without syntax errors; `rake gem:precompile` appears.

- [ ] **Step 5: Commit**

```bash
git add Rakefile
git commit -m "build: pin upstream zvec commit in Rakefile precompile task"
```

---

## Task 2: Pin zvec in the CI workflow

**Files:**
- Modify: `.github/workflows/precompile.yml:35` (linux clone line)
- Modify: `.github/workflows/precompile.yml:78` (macos clone line)

- [ ] **Step 1: Read current workflow to confirm line numbers**

Run: `sed -n '30,90p' .github/workflows/precompile.yml`

Expected: two separate `git clone --depth 1 https://github.com/alibaba/zvec /tmp/zvec` lines, one in `native-linux` (inside a bash heredoc), one in `native-macos`.

- [ ] **Step 2: Introduce a workflow-level env var for the pinned SHA**

At the top of `.github/workflows/precompile.yml`, right after the `on:` block and before `jobs:`, add an `env:` block:

```yaml
env:
  ZVEC_REF: "ZVEC_SHA_PLACEHOLDER"  # must match Rakefile ZVEC_REF
```

Use the same SHA chosen in Task 1 Step 1.

- [ ] **Step 3: Replace the linux clone with pinned fetch**

In the `native-linux` job's bash heredoc (currently around line 35), replace:

```bash
git clone --depth 1 https://github.com/alibaba/zvec /tmp/zvec
cd /tmp/zvec && mkdir build && cd build
```

with:

```bash
git clone https://github.com/alibaba/zvec /tmp/zvec
cd /tmp/zvec
git checkout ${{ env.ZVEC_REF }}
mkdir build && cd build
```

- [ ] **Step 4: Replace the macos clone with pinned fetch**

In the `native-macos` job's `Build zvec from source` step (currently around line 78), replace:

```bash
git clone --depth 1 https://github.com/alibaba/zvec /tmp/zvec
cd /tmp/zvec && mkdir build && cd build
```

with:

```bash
git clone https://github.com/alibaba/zvec /tmp/zvec
cd /tmp/zvec
git checkout ${ZVEC_REF}
mkdir build && cd build
```

(Note: `${{ env.ZVEC_REF }}` inside heredocs runs at workflow-parse time; plain shell variables like `${ZVEC_REF}` work because GitHub Actions injects `env:` into the step's environment.)

- [ ] **Step 5: Lint the workflow YAML**

Run: `ruby -ryaml -e "YAML.load_file('.github/workflows/precompile.yml'); puts 'OK'"`

Expected: `OK`.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/precompile.yml
git commit -m "ci: pin upstream zvec commit in precompile workflow"
```

---

## Task 3: Stop swallowing gem-push failures

**File:**
- Modify: `.github/workflows/precompile.yml:131-135` (the `Publish to RubyGems` step)

- [ ] **Step 1: Confirm the current broken behavior**

Run: `sed -n '128,136p' .github/workflows/precompile.yml`

Expected: you see `gem push "$gem" || true`. The `|| true` suppresses all failures.

- [ ] **Step 2: Replace the publish loop with a fail-fast version**

Replace the `Publish to RubyGems` step's `run:` block with:

```bash
set -euo pipefail
shopt -s nullglob
gems=(gems/*.gem)
if [ ${#gems[@]} -eq 0 ]; then
  echo "No gems found to publish" >&2
  exit 1
fi
for gem in "${gems[@]}"; do
  echo "Publishing $gem..."
  gem push "$gem"
done
```

This fails the job if no gems are found, or if any `gem push` fails. If the failure is "version already pushed" you want the job to fail loudly so you notice, not succeed silently.

- [ ] **Step 3: Lint the workflow YAML**

Run: `ruby -ryaml -e "YAML.load_file('.github/workflows/precompile.yml'); puts 'OK'"`

Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/precompile.yml
git commit -m "ci: fail fast on gem push errors instead of swallowing them"
```

---

## Task 4: Document Darwin single-Ruby constraint and install instructions

**Files:**
- Modify: `README.md` (add a new "Installation" subsection or edit the existing one if present)

- [ ] **Step 1: Read current README installation section**

Run: `grep -n -A 20 -i "install" README.md | head -60`

Note whether an "Installation" heading already exists and where.

- [ ] **Step 2: Add or update the Installation section**

If an `## Installation` heading does not exist, add one near the top (after the title/summary). If it exists, append the content below to it.

Content to add (adjust surrounding prose to match existing README voice):

```markdown
## Installation

Add to your Gemfile:

```ruby
gem "zvec-ruby"
```

Then `bundle install`.

### Precompiled platform support

Starting with v0.2.1, `zvec-ruby` ships precompiled gems so no C++ toolchain is required on install for supported platforms:

| Platform        | Ruby versions | Notes                               |
| --------------- | ------------- | ----------------------------------- |
| `x86_64-linux`  | 3.1, 3.2, 3.3, 3.4 | Built via `rake-compiler-dock` |
| `aarch64-linux` | 3.1, 3.2, 3.3, 3.4 | Built via `rake-compiler-dock` |
| `arm64-darwin`  | **3.3 only**  | Built on macOS runner               |
| `x86_64-darwin` | **3.3 only**  | Built on macOS runner               |

On any other platform, or on Darwin with a non-3.3 Ruby, Bundler will fall
back to the source gem, which requires CMake, a C++17 compiler, and the
pinned upstream zvec C++ library. See `script/build_zvec.sh`.
```

(Replace the inner triple backticks with a four-backtick fence if your README already uses triple-backtick fenced blocks, to avoid nesting issues.)

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document precompiled platform support and Darwin Ruby 3.3 limitation"
```

---

## Task 5: Configure the rubygems.org publish secret

**This is a manual GitHub UI step, not a code change.** Included so it isn't forgotten before the first tagged release.

- [ ] **Step 1: Generate a scoped API key on rubygems.org**

In a browser, go to `https://rubygems.org/settings/edit`, scroll to "API keys", create a new key with **only** the `Push rubygem` scope, scoped to the `zvec-ruby` gem. Name it `github-actions-zvec-ruby`.

Copy the key value (shown once).

- [ ] **Step 2: Add the secret to the GitHub repo**

In a browser, go to `https://github.com/johannesdwicahyo/zvec-ruby/settings/secrets/actions`. Click "New repository secret":

- Name: `RUBYGEMS_API_KEY`
- Value: the key from Step 1

Click "Add secret".

- [ ] **Step 3: Verify the workflow references the correct secret name**

Run: `grep -n "RUBYGEMS_API_KEY" .github/workflows/precompile.yml`

Expected: one match, on the `GEM_HOST_API_KEY: ${{ secrets.RUBYGEMS_API_KEY }}` line inside the `release` job.

- [ ] **Step 4: Nothing to commit** — this task has no code changes.

---

## Task 6: Local single-platform dry-run

**Why:** Catches Rakefile/zvec/build breakage before consuming CI time and before the first real tag.

**Prerequisites:** Docker Desktop running locally. ~20 GB free disk, ~30 min.

- [ ] **Step 1: Ensure Docker is running**

Run: `docker info >/dev/null 2>&1 && echo "docker ok" || echo "docker missing"`

Expected: `docker ok`. If missing, start Docker Desktop and retry.

- [ ] **Step 2: Run the precompile task for one Linux platform**

Run: `cd /Users/johannesdwicahyo/Projects/2026/ruby-gems/zvec-ruby && bundle install && bundle exec rake gem:precompile`

Note: The task from Task 1 Step 3 skips darwin entries, so this runs `rake-compiler-dock` for `x86_64-linux` and `aarch64-linux`. If you only want one, temporarily edit the task to iterate over `%w[x86_64-linux]` just for the dry-run (revert before committing).

Expected: 15–30 minutes of Docker build output. Final line mentions `pkg/zvec-ruby-0.2.0-x86_64-linux.gem` (or similar).

- [ ] **Step 3: Inspect the built gem contents**

Run: `gem contents --version 0.2.0 pkg/zvec-ruby-0.2.0-x86_64-linux.gem 2>/dev/null || tar -tzf pkg/zvec-ruby-*-x86_64-linux.gem | head -40`

Expected: the output lists per-Ruby-version `.so` files like `lib/zvec/3.1/zvec_ext.so`, `lib/zvec/3.2/zvec_ext.so`, etc.

- [ ] **Step 4: Check gem size against rubygems.org 100 MB limit**

Run: `ls -lh pkg/zvec-ruby-*-x86_64-linux.gem`

Expected: a size. Record it. If it exceeds 95 MB, flag in Task 7; if under, continue.

- [ ] **Step 5: Smoke-test install from the built gem (optional but recommended)**

In a fresh directory:

```bash
mkdir /tmp/zvec-install-test && cd /tmp/zvec-install-test
gem install --local /path/to/pkg/zvec-ruby-*-x86_64-linux.gem --install-dir ./gems --no-document
GEM_PATH=./gems ruby -e "require 'zvec'; puts Zvec::VERSION"
```

Expected: prints `0.2.0` with no compile step. (Note: on macOS a Linux gem won't load natively — use a Linux VM/container, or skip this step and rely on the install test in Task 9.)

- [ ] **Step 6: Nothing to commit.** Delete the `pkg/*.gem` artifacts if they shouldn't be checked in:

```bash
git status pkg/
# If pkg/ is tracked, confirm the .gitignore covers it:
grep -q "^pkg/" .gitignore || echo "pkg/" >> .gitignore
```

If `.gitignore` was modified: `git add .gitignore && git commit -m "chore: ignore pkg/ build artifacts"`.

---

## Task 7: Address gem-size risk if it materializes

**Conditional on Task 6 Step 4.** Skip this task entirely if the gem is under 95 MB.

**Files (if needed):**
- Modify: `Rakefile` — add a `strip` step in the cross-compile hook.

- [ ] **Step 1: Identify the strip target**

Inside the rake-compiler-dock container, the compiled `.so` lives at `tmp/<platform>/zvec_ext/<ruby-version>/zvec_ext.so`. Strip reduces debug symbols without affecting runtime.

- [ ] **Step 2: Add a strip step inside the rake-compiler-dock script**

rake-compiler's Ruby-level hooks don't expose a clean "post-compile, pre-package" point, so the reliable fix is to strip symbols inside the container script in `Rakefile`'s `gem:precompile` task and then re-run `rake native:<plat> gem` so the repackaged gem picks up the stripped `.so` files. Replace the `RakeCompilerDock.sh` invocation from Task 1 Step 3 with:

```ruby
RakeCompilerDock.sh <<~SCRIPT, platform: plat
  set -e
  git clone #{ZVEC_REPO} /tmp/zvec
  cd /tmp/zvec
  git checkout #{ZVEC_REF}
  mkdir build && cd build
  cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
  make -j$(nproc)
  make install
  ldconfig 2>/dev/null || true

  cd /payload
  export ZVEC_DIR=/tmp/zvec
  bundle install
  rake native:#{plat} gem RUBY_CC_VERSION=#{CROSS_RUBIES.join(':')}

  # Strip debug symbols to reduce gem size
  find tmp/#{plat}/zvec_ext -name '*.so' -exec strip --strip-unneeded {} \\;

  # Repack any gems that were already built to pick up stripped .so
  rm -f pkg/zvec-ruby-*-#{plat}.gem
  rake native:#{plat} gem RUBY_CC_VERSION=#{CROSS_RUBIES.join(':')}
SCRIPT
```

- [ ] **Step 3: Re-run Task 6's single-platform build and re-check size**

Run the same command as Task 6 Step 2, then Task 6 Step 4.

Expected: gem size is measurably smaller. If still over 95 MB, open a RubyGems.org support request to increase the size limit for `zvec-ruby` — link the request in `CHANGELOG.md` for posterity. Blocks tag release until resolved.

- [ ] **Step 4: Commit**

```bash
git add Rakefile
git commit -m "build: strip debug symbols to keep precompiled gems under size limit"
```

---

## Task 8: Trial release via workflow_dispatch (no real publish)

**Why:** Validates the CI matrix end-to-end before committing to a tag. The existing workflow already has `workflow_dispatch:` enabled alongside the tag trigger.

**Safety:** The `release` job has `if: startsWith(github.ref, 'refs/tags/v')`, so a `workflow_dispatch` run on a branch will build and upload artifacts but will NOT push to rubygems.org. This is exactly the safety gate we need.

- [ ] **Step 1: Push the current branch to GitHub**

Run:
```bash
git push origin main
```

(Replace `main` with the current branch name if different.)

- [ ] **Step 2: Trigger the workflow manually**

In the GitHub UI: Actions → "Precompile Native Gems" → "Run workflow" → select `main` → Run.

Alternative CLI: `gh workflow run precompile.yml --ref main`

- [ ] **Step 3: Watch the run to completion**

Run: `gh run watch` (pick the Precompile Native Gems run)

Expected: all 4 native jobs + source-gem job succeed. The `release` job is skipped due to the `if:` guard on the tag ref — this is correct.

- [ ] **Step 4: Download and inspect the artifacts**

Run: `gh run download <run-id> -D /tmp/zvec-trial-gems && ls -lh /tmp/zvec-trial-gems`

Expected: 5 `.gem` files (source + 4 platforms), each under 95 MB.

- [ ] **Step 5: Nothing to commit.** Any fixes required become new tasks.

---

## Task 9: Install test on the actual target server

**Why:** Proves end-to-end that a platform gem loads without a toolchain on the real deployment environment.

- [ ] **Step 1: Identify the server's architecture and Ruby version**

On the server, run: `uname -m && ruby -v`

Expected: e.g., `x86_64` and `ruby 3.3.x`. Match this to one of the 4 supported platforms. If Ruby is not 3.3 and the arch is Darwin, you'll hit the single-Ruby limitation from Task 4 — switch Ruby or upgrade to Ruby 3.3 first.

- [ ] **Step 2: Upload the relevant trial gem to the server**

From the artifacts in Task 8 Step 4:

```bash
scp /tmp/zvec-trial-gems/zvec-ruby-0.2.0-<platform>.gem user@server:/tmp/
```

- [ ] **Step 3: Install the gem on the server**

On the server: `gem install --local /tmp/zvec-ruby-0.2.0-<platform>.gem`

Expected: "Successfully installed zvec-ruby-0.2.0-<platform>" with **no** compile step, **no** `cmake`, **no** `rake-compiler`.

- [ ] **Step 4: Require it**

On the server: `ruby -e "require 'zvec'; puts Zvec::VERSION"`

Expected: `0.2.0` (or whatever version was in `lib/zvec/version.rb` at the trial).

- [ ] **Step 5: Nothing to commit.** If the require fails, the platform gem is broken and all preceding tasks need debugging; do not tag a release yet.

---

## Task 10: First real release

**Prerequisite:** Tasks 1–9 all complete and green.

**Files:**
- Modify: `lib/zvec/version.rb`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Bump version**

Edit `lib/zvec/version.rb`:

```ruby
module Zvec
  VERSION = "0.2.1"
end
```

- [ ] **Step 2: Update CHANGELOG.md**

Prepend a new entry:

```markdown
## 0.2.1 - 2026-04-17

- **Precompiled platform gems.** First release with working precompiled
  gems for `x86_64-linux`, `aarch64-linux`, `arm64-darwin`, and
  `x86_64-darwin`. Linux gems support Ruby 3.1–3.4; Darwin gems require
  Ruby 3.3.
- **Pinned upstream zvec.** CI and Rakefile now pin zvec to a specific
  commit (`ZVEC_SHA_PLACEHOLDER`) for reproducible builds.
- **Release workflow hardened.** `gem push` failures no longer swallowed.
```

(Replace `ZVEC_SHA_PLACEHOLDER` with the real SHA from Task 1.)

- [ ] **Step 3: Commit the release**

```bash
git add lib/zvec/version.rb CHANGELOG.md
git commit -m "release: v0.2.1 — precompiled platform gems"
```

- [ ] **Step 4: Tag and push**

```bash
git tag v0.2.1
git push origin main
git push origin v0.2.1
```

- [ ] **Step 5: Monitor the tag-triggered workflow**

Run: `gh run watch`

Expected: all 5 build jobs succeed, then the `release` job runs `gem push` for all 5 gems.

- [ ] **Step 6: Verify on rubygems.org**

Run: `gem info zvec-ruby --remote --all | head -30`

Expected: version `0.2.1` appears with platforms `ruby`, `x86_64-linux`, `aarch64-linux`, `arm64-darwin`, `x86_64-darwin`.

- [ ] **Step 7: Push to gem.coop manually**

Use the command from the project's local `CLAUDE.md`:

```bash
GEM_HOST_API_KEY=<key-from-CLAUDE.md> \
  gem push zvec-ruby-0.2.1.gem \
  --host https://beta.gem.coop/@johannesdwicahyo
```

(Source gem only is sufficient for gem.coop since it's used as a mirror, not a primary install source for your server. Adjust if you want all 5 there too.)

- [ ] **Step 8: Install on the real server**

On the server: `gem install zvec-ruby` (no `--local` this time — pulls from rubygems.org)

Expected: downloads the matching platform gem, no compile, `require "zvec"` works.

---

## Post-release notes

- **Bumping zvec later:** edit `ZVEC_REF` in both `Rakefile` and `.github/workflows/precompile.yml`, run Task 6 locally to validate, then cut a new release via Task 10.
- **Adding Darwin multi-Ruby support:** out of scope per spec decision C. If users report pain, revisit by matrixing the macOS jobs over Ruby versions and fat-packaging the resulting `.bundle`s.
- **Caching zvec build in CI:** follow-up optimization. Use `actions/cache` keyed on `ZVEC_REF` + platform to skip the 15-min cmake build on reruns.
