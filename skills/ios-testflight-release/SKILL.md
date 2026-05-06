---
name: ios-testflight-release
description: Use when the user asks to update TestFlight, publish/release the iOS app, cut a TestFlight build, create an iOS release tag, or says "发版", "更新 TestFlight", "打包提测", or similar. This project releases by pushing code to main and creating an ios/vX.Y.Z tag that triggers GitHub Actions TestFlight upload.
---

# iOS TestFlight Release

Use this skill for this repository's iOS release flow.

## Release Policy

- Releases are driven by Git tags matching `ios/v*`, for example `ios/v1.0.1`.
- The GitHub Actions workflow builds and uploads the build to TestFlight.
- Public Beta submission is manual. Do not automatically submit Beta App Review unless the user explicitly asks for full external distribution automation.
- If the user does not specify a version, bump the current iOS marketing version by `+0.0.1`.
- Commit the version change to `main`, push it, then push the matching tag.

## Safety Checks

1. Run `git status --short --branch`.
2. Work from the latest `origin/main`.
3. If the local `main` is diverged, do not force-reset it. Use a clean worktree or detached `origin/main`, commit there, and push `HEAD:main`.
4. Check whether the intended tag already exists locally or remotely before creating it:

```bash
git tag --list ios/vX.Y.Z
git ls-remote --tags origin ios/vX.Y.Z
```

If either command shows the tag, stop and report that the release tag already exists.

## Version Selection

If the user provides a version, normalize it:

- `1.0.1` -> `1.0.1`
- `v1.0.1` -> `1.0.1`
- `ios/v1.0.1` -> `1.0.1`

If the user does not provide a version:

1. Read the Release build setting for the app target:

```bash
xcodebuild -project nodeseek.xcodeproj -scheme nodeseek -configuration Release -showBuildSettings
```

2. Extract `MARKETING_VERSION`.
3. Normalize two-part versions to three-part versions:

- `1.0` -> `1.0.0`
- `1.2.3` -> `1.2.3`

4. Increment the patch component by 1:

- `1.0` -> `1.0.1`
- `1.2.3` -> `1.2.4`

The release tag is `ios/v<version>`.

## Update Project Version

Set the project marketing version to the selected version before tagging. Prefer the project's existing fastlane tooling when available:

```bash
bundle exec fastlane run increment_version_number version_number:X.Y.Z xcodeproj:nodeseek.xcodeproj
```

If local Ruby/bundler is unavailable, update all app/test target `MARKETING_VERSION` entries in `nodeseek.xcodeproj/project.pbxproj` consistently and verify the diff only changes version values.

Do not manually edit build number for this workflow. GitHub Actions passes the build number from `GITHUB_RUN_NUMBER`.

## Commit, Push, Tag

After the version file change:

```bash
git diff --check
git status --short
git add nodeseek.xcodeproj/project.pbxproj
git commit -m "Release iOS X.Y.Z"
git push origin HEAD:main
git tag ios/vX.Y.Z
git push origin ios/vX.Y.Z
```

The tag push starts the `TestFlight` GitHub Actions workflow.

## After Push

Tell the user:

- the commit SHA
- the tag name
- that GitHub Actions should upload the build to TestFlight
- that final Public Beta submission is still manual in App Store Connect

If asked for the next manual step, direct them to App Store Connect > the app > TestFlight, select the uploaded build, add it to `Public Beta`, confirm the test information from the workflow summary, and submit Beta App Review.
