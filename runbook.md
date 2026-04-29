# Runbook: Publish a New Version on GitHub

This runbook explains how to publish a new release for `ai-session-notifier` using the existing GitHub Actions workflows.

## Overview

Release flow:

1. Manually trigger workflow **Tag Release** with a version.
2. Workflow creates and pushes tag `vX.Y.Z`.
3. Tag push automatically triggers workflow **Release**.
4. GitHub Release is published with artifacts and checksums.

Workflows used:

- `.github/workflows/tag.yml`
- `.github/workflows/release.yml`

## Prerequisites

- You have write access to the repository.
- You are releasing from branch `main`.
- Target tag does not already exist.
- Version format is either:
  - `1.2.3`
  - `v1.2.3`

## Step-by-step

### 1) Prepare the version

Choose the next semantic version (MAJOR.MINOR.PATCH), for example:

- `1.0.1` for fixes
- `1.1.0` for backward-compatible features
- `2.0.0` for breaking changes

### 2) Trigger the tag workflow

1. Open GitHub repository.
2. Go to **Actions**.
3. Select workflow **Tag Release**.
4. Click **Run workflow**.
5. Enter `version` as `1.2.3` or `v1.2.3`.
6. Run on branch `main`.

What happens in this workflow:

- Normalizes version to `vX.Y.Z` if needed.
- Validates format.
- Fails if tag already exists.
- Creates annotated tag and pushes it.

### 3) Confirm release workflow runs

After the tag is pushed, workflow **Release** starts automatically (triggered by `push` on tags matching `v*`).

Verify it completes successfully in **Actions**.

### 4) Verify published GitHub Release

Open **Releases** and confirm a new release exists for tag `vX.Y.Z` with assets:

- `ai-session-notifier-vX.Y.Z.tar.gz`
- `ai-session-notifier-vX.Y.Z.zip`
- `checksums.txt`

Also confirm release notes were auto-generated.

### 5) Quick post-release smoke check

- Download one artifact and inspect contents.
- Confirm included files:
  - `install.sh`
  - `quick-install.sh`
  - `toggle-notify.sh`
  - `telegram-notify.plugin.js`
  - `README.md`
  - `LICENSE`
- Optionally verify checksums:
  - `sha256sum -c checksums.txt` (after adjusting paths locally as needed).

## Troubleshooting

### Invalid version format

Symptom:
- **Tag Release** fails with invalid version error.

Fix:
- Use only `1.2.3` or `v1.2.3`.

### Tag already exists

Symptom:
- **Tag Release** fails because tag exists.

Fix:
- Pick the next version and rerun.
- Do not reuse an existing tag.

### Workflow started from wrong branch

Symptom:
- **Tag Release** job is skipped/fails due to branch check.

Fix:
- Run workflow from `main`.

### Release workflow failed

Symptom:
- **Release** fails in Actions.

Checks:
- Validate scripts step (`bash -n install.sh quick-install.sh toggle-notify.sh`).
- Confirm files expected by packaging step still exist at repo root.
- Re-run workflow after fixing the issue in `main` and creating a new tag.

## Rollback / Recovery

If a bad release was published:

1. Fix code on `main`.
2. Publish a new patch version (`vX.Y.(Z+1)`).
3. Avoid deleting/reusing tags unless absolutely necessary and coordinated.

## Notes

- Release artifacts are built in CI from the tagged commit.
- Keep this runbook updated if workflow filenames, triggers, or artifact names change.
