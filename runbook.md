# Runbook

## Generate a new release tag

Set the version tag and push it:

```bash
TAG="v1.0.2"
git tag -a "$TAG" -m "Release $TAG"
git push origin "$TAG"
```

## Artifact automation

When the tag is pushed, GitHub Actions runs the release workflow automatically and publishes the release artifacts.

## Verify

- Check the **Actions** page to confirm the release workflow completed successfully.
- Check the **Releases** page to confirm the new release and generated artifacts are present.
