# Refresh the API client

`Sources/JellyseerrAPI/openapi.json` is the JSON conversion of
[Seerr v3.5.1's specification](https://github.com/seerr-team/seerr/blob/v3.5.1/seerr-api.yml).
The Swift sources are checked in and generated with `swift-openapi-generator` 1.14.2.
SwiftPM compiles these sources without running the generator.

Build the pinned generator in a temporary directory:

```sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git clone --depth 1 --branch 1.14.2 https://github.com/apple/swift-openapi-generator.git "$work/generator"
xcrun swift build --package-path "$work/generator"
make openapi-generate OPENAPI_GENERATOR="$work/generator/.build/debug/swift-openapi-generator"
```

Run `make openapi-generate` from the repository root. If the generator is already
on `PATH`, omit `OPENAPI_GENERATOR`. Do not hand-edit files in `Generated`.
Generator 1.14.2 splits types into multiple files at namespace boundaries.

To update the specification, download the desired release's `seerr-api.yml`,
convert it to JSON with a YAML parser that preserves timestamp examples as strings,
and replace `openapi.json`. Record the release here and regenerate the client.

Build with isolated artifacts to check the generated client against the pinned runtime:

```sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
xcrun swift build --package-path Packages/JellyseerrAPI --scratch-path "$work/build"
```
