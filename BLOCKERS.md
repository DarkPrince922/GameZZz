# BLOCKERS

> **RESOLVED 2026-11-01.** The repository was pushed and CI ran; run #25 is green
> (lint, data/audio, GUT, smoke, bot playthrough, debug APK). The entries below
> are kept as a record of what the environment could not do at the time.

## 1. No GitHub repository, remote or token — CI has never run (blocking stage sign-off)

**What the spec asks:** push `stage-N`, let GitHub Actions run lint/GUT/smoke/
audio/APK, wait for green with `gh run watch`, then merge and tag.

**What the environment provides:** an empty local project folder, no `origin`
remote, no GitHub credentials, no `gh` session. `git init` + local commits are
all that is possible. Networking from the sandbox is limited to package
registries, so a push or an API call cannot be simulated either.

**Consequence:** every "готово, когда" criterion that depends on CI (green
pipeline, downloadable APK, stage release asset) is **unverified**. The code,
tests and workflows are in place, but the first real CI run is the first real
proof.

**What I need from you:** create an empty repository, add the remote, and push:

```bash
git remote add origin git@github.com:<you>/<repo>.git
git push -u origin main
git push origin --tags
```

The first push will trigger `ci.yml`. Expect the first red build — see blocker 3
for the class of failures most likely to appear.

## 2. Godot 4.5 is not installed here — GUT, smoke and bot tests are unexecuted

**What I tried:** checked for `godot`/`godot4` binaries (absent), tried to
install the engine (`godot` is not on PyPI; the sandbox blocks non-registry
hosts, so the official binary cannot be downloaded).

**What that means:** `tests/unit/*.gd`, `tools/smoke_test.gd` and
`tools/bot_test.gd` have never been executed. They pass gdtoolkit's parser
(gdlint: "Success: no problems found" over `scripts tests tools`), and the
data-level rules they check were verified independently in Python
(`tools/validate_data.py`, `tools/validate_audio.py`, `tools/check_refs.py`),
but GDScript runtime behaviour is untested.

Likely first failures, in order of probability:
1. A dynamic member access the GDScript analyzer rejects (I removed the known
   cases where a statically typed variable received a script-defined method).
2. Physics timing in `test_player_movement.gd` (frame counts, ledge position).
3. Node lifetime in the smoke test for `level.tscn` (entities freeing
   themselves mid-run).
4. The bot getting stuck on a jump that is reachable on paper but not with the
   actual acceleration curve.

Each of these is a one-line fix, and `NOTES.md` records how the numbers were
derived.

## 3. Documentation site partly unreachable

`docs.godotengine.org` returned "источник недоступен" for several pages while
writing this. Facts were therefore taken from primary sources on GitHub instead
(Godot 4.5 `platform/android/java/app/config.gradle`, godot-ci `Dockerfile`,
GUT source for CLI options, godot-docs raw RST). What could not be confirmed
from a primary source is listed in `NOTES.md` under "Assumptions to verify on
first CI run".

## Stop-rule status

The spec says: if the same error is not fixed in 5 attempts, stop and report.
Nothing reached that state — but the *environmental* blockers above (no remote,
no engine) cannot be fixed from inside the project, which is why this file
exists and why `PROGRESS.md` does not claim a green pipeline.
