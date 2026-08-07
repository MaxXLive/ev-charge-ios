fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios verify

```sh
[bundle exec] fastlane ios verify
```

Verify App Store Connect API key auth and that the app record exists

### ios build

```sh
[bundle exec] fastlane ios build
```

Build a signed release archive (.ipa)

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Generate localized App Store screenshots via UI test (snapshot) + branded background + title

### ios reframe

```sh
[bundle exec] fastlane ios reframe
```

Re-decorate existing raw screenshots (frame + branded background + title) without re-capturing

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build + upload to TestFlight

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload metadata + screenshots only (no binary)

### ios release

```sh
[bundle exec] fastlane ios release
```

Full release: build, upload binary + metadata + screenshots, submit for review

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
