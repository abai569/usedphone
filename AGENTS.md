# Project Rules

## Flutter Android Builds

- Do not run local Android APK builds in this workspace.
- The local environment does not provide an Android SDK, so `flutter build apk` is intentionally skipped locally.
- Android APK builds must run through the GitHub Actions workflow with the configured release keystore and `API_BASE_URL` repository variable.
- Before committing or publishing Flutter changes, still run `flutter pub get`, `flutter analyze`, and `flutter test` locally.
- Release exception: when the user explicitly requests skipping Flutter validation, skip local `flutter pub get`, `flutter analyze`, and `flutter test`; rely on the GitHub Actions release workflow to build and validate the APK.
- Report the skipped local APK build explicitly in the final verification summary.

## 私有后端

- `closed/` 目录包含私有后端源码和二进制文件。
- 禁止向公开仓库添加、提交或推送 `closed/` 目录内容。
- 如需构建 Linux AMD64 后端二进制，在本地使用 `CGO_ENABLED=0` 编译。
- `catalog.json` is private deployment data and must not be copied to or committed in the public repository.
