fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android build_only

```sh
[bundle exec] fastlane android build_only
```

AAB 파일 경로 찾기

Flutter 빌드만 (업로드 없이)

### android release

```sh
[bundle exec] fastlane android release
```

Flutter 빌드 및 Google Play에 업로드 (제출 없음)

### android submit

```sh
[bundle exec] fastlane android submit
```

Flutter 빌드 및 Google Play에 자동 제출 (리뷰 제출 포함)

### android internal

```sh
[bundle exec] fastlane android internal
```

내부 테스트 트랙에 배포

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
