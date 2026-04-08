# Android Python Docker Builder

[Documentacao em portugues](./README.md)

Reproducible Docker-based cross-build environment for running CPython in the plain Android shell, with no Termux, no APK, and no Gradle. The primary target is Android `x86_64` running inside Redroid, while the repository is structured to also build `arm64-v8a`, `armeabi-v7a`, and `x86`.

## What this repository provides

- A Dockerized build environment for CPython on Android
- Cross-compilation with the Android NDK
- Portable runtime bundles for Android shell usage
- `full`, `minimal`, and `slim` runtime variants
- Automated Redroid deploy and smoke-test scripts
- Global wrappers in `/system/bin/python3`, `/system/bin/python`, and `/system/bin/pip`
- Bundled pure-Python packages:
  - `faker`
  - `requests`
  - `jinja2`

## Technical choices

- CPython: `3.12.12`
- Android NDK: `r27d`
- Android API baseline: `24`
- Primary tested ABI: `x86_64`
- Additional supported build targets:
  - `arm64-v8a`
  - `armeabi-v7a`
  - `x86`

The GitHub release workflow currently publishes prebuilt assets for:

- `x86_64`
- `arm64-v8a`

The runtime uses shell launchers to set:

- `PYTHONHOME`
- `PYTHONPATH`
- `LD_LIBRARY_PATH`
- `LD_PRELOAD`
- `TMPDIR`
- `LANG`
- `LC_ALL`
- `SSL_CERT_FILE`

This is more reliable on Android than depending on linker search behavior alone.

## Repository layout

```text
.
├── .github/workflows/
├── Dockerfile
├── MAIN.md
├── Makefile
├── README.md
├── README.en.md
├── config/
├── docker-compose.yml
├── output/
├── patches/
├── scripts/
└── tests/
```

Important entry points:

- `scripts/build-all.sh`: full build for one ABI
- `scripts/build-matrix.sh`: serial multi-ABI build
- `scripts/package-runtime.sh`: runtime packaging
- `scripts/redroid-push.sh`: copy runtime to Redroid and install wrappers
- `scripts/redroid-test.sh`: deploy and validate the runtime inside Android
- `scripts/redroid-enable-pip.sh`: bootstrap `pip` inside the deployed runtime

## Requirements

Host requirements:

- Docker
- Docker Compose v2
- Internet access for source downloads

Android target requirements:

- A writable path such as `/data/local/tmp`
- Shell access via `docker exec`
- Working network access if you want to run TLS or HTTPS smoke tests

## Build instructions

### 1. Build the builder image

```bash
docker compose build builder
```

### 2. Start the builder container

```bash
docker compose up -d builder
```

### 3. Build the default target (`x86_64`)

```bash
docker compose exec builder bash -lc "./scripts/build-all.sh"
```

Equivalent Make targets:

```bash
make compose-build
make compose-up
make build
```

## Build a different ABI

Example for `arm64-v8a`:

```bash
docker compose exec builder bash -lc "ANDROID_ABI=arm64-v8a ./scripts/build-all.sh"
```

Build all configured ABIs serially:

```bash
docker compose exec builder bash -lc "./scripts/build-matrix.sh"
```

## Build output

After a successful build, artifacts are written to `output/dist/`, for example:

- `python-android-x86_64-full.tar.gz`
- `python-android-x86_64-minimal.tar.gz`
- `python-android-x86_64-slim.tar.gz`
- `python-android-arm64-v8a-full.tar.gz`
- `python-android-arm64-v8a-minimal.tar.gz`
- `python-android-arm64-v8a-slim.tar.gz`
- `SHA256SUMS`
- `ARTIFACTS.txt`

The unpacked runtime trees are also available locally under:

- `output/runtime/full/`
- `output/runtime/minimal/`
- `output/runtime/slim/`

Note: this repository uses `output/` as the canonical build output directory. There is no `out/` directory in this project.

## Runtime variants

- `full`
  - Expanded stdlib
  - Development headers
  - pkg-config files
  - helper tools
- `minimal`
  - Main distribution target
  - Stdlib mostly zipped
  - Keeps `lib-dynload`, `site-packages`, `ensurepip`, and `venv`
- `slim`
  - Smaller runtime
  - Removes headers, manpages, pkg-config files, and extra helper binaries

## Included batteries and packages

The build is prepared for common automation and data-processing workflows.

Included stdlib modules relevant to your use case:

- `json`
- `sqlite3`
- `csv`
- `re`
- `random`
- `string`
- `secrets`
- `subprocess`
- `os`
- `sys`
- `pathlib`
- `time`
- `datetime`
- `base64`
- `hashlib`
- `http.server`
- `urllib.request`
- `collections`
- `itertools`

Bundled extra packages:

- `faker`
- `requests`
- `jinja2`

Their pure-Python dependencies are bundled as well:

- `urllib3`
- `certifi`
- `idna`
- `charset-normalizer`
- `MarkupSafe`

Each runtime also includes `BUNDLED-PACKAGES.txt` with the pinned versions that were installed into the final package.

## Deploy to Redroid

By default, deployment uses the `minimal` runtime and installs it under:

```text
/data/local/tmp/<abi>/python-android-<abi>
```

Example for a running Redroid container:

```bash
REDROID_CONTAINER=android-15 ./scripts/redroid-push.sh
```

Example for `arm64-v8a`:

```bash
REDROID_CONTAINER=android-15 ANDROID_ABI=arm64-v8a ./scripts/redroid-push.sh
```

The deploy step also installs global wrappers:

- `/system/bin/python3`
- `/system/bin/python`
- `/system/bin/pip`

## Use the prebuilt runtime directly in Redroid

If you already have a generated runtime and only want to install it into a running Redroid container, you do not need to rebuild anything.

Example using the `minimal` runtime for `x86_64`:

```bash
REDROID_CONTAINER=android-15 ANDROID_ABI=x86_64 ./scripts/redroid-push.sh
```

Example using the `minimal` runtime for `arm64-v8a`:

```bash
REDROID_CONTAINER=android-15 ANDROID_ABI=arm64-v8a ./scripts/redroid-push.sh
```

Manual equivalent:

```bash
docker exec android-15 sh -lc 'rm -rf /data/local/tmp/x86_64/python-android-x86_64 && mkdir -p /data/local/tmp/x86_64/python-android-x86_64'
docker cp ./output/runtime/minimal/. android-15:/data/local/tmp/x86_64/python-android-x86_64
docker exec android-15 sh -lc "cat > /system/bin/python3 <<'EOF'
#!/system/bin/sh
exec /data/local/tmp/x86_64/python-android-x86_64/bin/python3 \"\$@\"
EOF
chmod 0755 /system/bin/python3"
```

After deployment:

```bash
docker exec android-15 sh -lc 'python3 --version'
docker exec android-15 sh -lc 'python -c "import sys; print(sys.version)"'
docker exec android-15 sh -lc 'pip --version'
```

## Use the prebuilt runtime with ADB

For a physical device, emulator, or Android VM reachable through `adb`, use the generated runtime directory or one of the tarballs from `output/dist/`.

Example with the unpacked `minimal` runtime:

```bash
adb shell 'rm -rf /data/local/tmp/python3 && mkdir -p /data/local/tmp/python3'
adb push output/runtime/minimal/. /data/local/tmp/python3/
adb shell 'cat > /data/local/tmp/python3-activate <<'\''EOF'\''
#!/system/bin/sh
export PY_RUNTIME=/data/local/tmp/python3
exec "$PY_RUNTIME/bin/python3" "$@"
EOF
chmod 0755 /data/local/tmp/python3-activate'
adb shell '/data/local/tmp/python3-activate --version'
adb shell '/data/local/tmp/python3-activate -c "import json, sqlite3, ssl; print(\"ok\")"'
```

If you have root or a writable system partition, you can also install the wrappers into `/system/bin`:

```bash
adb root
adb remount
adb push output/runtime/minimal/. /system/opt/python3/
adb shell 'cat > /system/bin/python3 <<'\''EOF'\''
#!/system/bin/sh
exec /system/opt/python3/bin/python3 "$@"
EOF
chmod 0755 /system/bin/python3
ln -sf /system/bin/python3 /system/bin/python'
adb shell 'python3 --version'
```

For `pip` after an ADB deploy:

```bash
adb shell '/data/local/tmp/python3/bin/python3 -m ensurepip --upgrade'
adb shell '/data/local/tmp/python3/bin/python3 -m pip --version'
```

## Where users download prebuilt binaries

End users should download prebuilt runtimes from the GitHub `Releases` page.

Current CI behavior:

- pushes to `main` run the build workflow and upload temporary workflow artifacts
- pushes of tags matching `android-python-py*` create a GitHub Release and attach the prebuilt assets

To publish a release with downloadable prebuilt binaries:

```bash
git tag android-python-py3.12.12-r1
git push origin android-python-py3.12.12-r1
```

That release will publish assets for:

- `python-android-x86_64-full.tar.gz`
- `python-android-x86_64-minimal.tar.gz`
- `python-android-x86_64-slim.tar.gz`
- `python-android-arm64-v8a-full.tar.gz`
- `python-android-arm64-v8a-minimal.tar.gz`
- `python-android-arm64-v8a-slim.tar.gz`
- `SHA256SUMS`
- `ARTIFACTS.txt`

## Test inside Redroid

Run the automated smoke test:

```bash
REDROID_CONTAINER=android-15 ./scripts/redroid-test.sh
```

Or for `arm64-v8a`:

```bash
REDROID_CONTAINER=android-15 ANDROID_ABI=arm64-v8a ./scripts/redroid-test.sh
```

The test suite covers:

- `python3 --version`
- `print("hello from android")`
- core imports such as `json`, `ssl`, `sqlite3`, and `ctypes`
- file creation under a temporary directory
- `sys.path`
- execution of an external `.py` script
- sockets and real TLS/HTTPS checks
- `faker`, `requests`, and `jinja2`
- `/system/bin/python3` and `/system/bin/python`

## Enable and use pip on the target

Bootstrap `pip` in the deployed runtime:

```bash
REDROID_CONTAINER=android-15 ./scripts/redroid-enable-pip.sh
```

Install a pure-Python package on the target:

```bash
REDROID_CONTAINER=android-15 ./scripts/redroid-pip-install.sh urllib3
```

## Verified status

`x86_64` was built, deployed, and tested successfully in Redroid.

`arm64-v8a` was built successfully and packaged correctly. In the tested Redroid container, the shell still refused to execute the ARM ELF directly even though `ro.product.cpu.abilist` included `arm64-v8a`. The failing condition was:

- host shell architecture: `x86_64`
- target ELF architecture: `aarch64`
- Android linker result: machine mismatch / shell reports `not executable: 64-bit ELF file`

This means the image advertises `arm64-v8a`, but the shell execution path is not exposing native-bridge ARM binary execution to standalone ELF binaries.

## Embed it directly into an AOSP build

If you want Python to ship inside the image instead of being pushed later, the cleanest approach is to treat the runtime as a prebuilt directory tree.

This repository includes a ready-to-adapt example under:

- `patches/aosp/README.md`
- `patches/aosp/product-python3.mk`
- `patches/aosp/system-bin/python3`
- `patches/aosp/system-bin/python`
- `patches/aosp/system-bin/pip`

Recommended destination inside the image:

- runtime files: `/system/opt/python3`
- command wrappers:
  - `/system/bin/python3`
  - `/system/bin/python`
  - `/system/bin/pip`

Recommended AOSP flow:

1. Build the runtime in Docker.
2. Copy `output/runtime/minimal/` into a vendor or device repo inside the AOSP tree.
3. Copy the files from `patches/aosp/`.
4. Include `product-python3.mk` from your product makefile.
5. Rebuild the image.

The example uses `find-copy-subdir-files` so the whole runtime tree can be copied into the image without enumerating every file manually.

This is usually better than inventing an init-time extractor because:

- the files are visible in the final image layout
- updates are explicit
- no first-boot unpack step is needed
- debugging is simpler

## Known limitations

- This project does not try to force a fragile single-file static Python binary.
- The practical distribution format is a launcher plus shared runtime and stdlib payload.
- `readline`, `curses`, `tkinter`, and other desktop-oriented modules are intentionally out of scope.
- `pip` on Android is suitable mainly for pure-Python packages unless you also cross-build the native extensions they require.
- Secondary ABI support in Redroid does not automatically mean shell-executable binaries for that ABI.

## Suggested GitHub release flow

1. Build the desired ABI artifacts in Docker.
2. Validate them with `scripts/redroid-test.sh` on the matching runtime environment.
3. Publish the generated `.tar.gz` artifacts from `output/dist/`.
4. Attach `SHA256SUMS` and `ARTIFACTS.txt` to the release.
5. Tag releases using a format such as:
   - `v1.0.0`
   - `v1.0.0-x86_64`
   - `v1.0.0-arm64-v8a`

## Quick start

```bash
make compose-build
make compose-up
make build
REDROID_CONTAINER=android-15 make redroid-test
REDROID_CONTAINER=android-15 make redroid-pip
```
