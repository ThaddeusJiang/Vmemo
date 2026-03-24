# GitHub Actions upgrade to latest releases

## Summary

Updated all GitHub Actions used in repository workflows to their latest available release tags on 2026-03-24.

## Updated actions

- `actions/checkout` -> `v6.0.2`
- `actions/upload-artifact` -> `v7.0.0`
- `oven-sh/setup-bun` -> `v2.2.0`
- `EndBug/add-and-commit` -> `v10.0.0`
- `peter-evans/dockerhub-description` -> `v5.0.0`
- `erlef/setup-beam` -> `v1.23.0`
- `docker/setup-buildx-action` -> `v4.0.0`
- `docker/setup-qemu-action` -> `v4.0.0`
- `docker/login-action` -> `v4.0.0`
- `docker/build-push-action` -> `v7.0.0`

## Reason

GitHub announced Node.js 20 deprecation for JavaScript actions and will default runners to Node.js 24 starting on 2026-06-02.

Upgrading all workflow actions now keeps the repository aligned with current upstream releases instead of patching only the actions already mentioned in the warning.

## Notes

Release tags were verified from each action's GitHub Releases page before updating workflow files.
