# AOSP integration notes

This directory contains a pragmatic example for embedding the prebuilt Android Python runtime directly into an AOSP-based image.

## Recommended layout inside the AOSP tree

Copy the generated runtime payload into a vendor or device repository, for example:

```text
vendor/<your-org>/python3/
├── runtime/
│   └── minimal/
└── aosp/
    ├── product-python3.mk
    └── system-bin/
        ├── python
        ├── python3
        └── pip
```

Suggested source for `runtime/minimal/`:

- `output/runtime/minimal/`

This repository already prepares a shell-safe runtime layout, so the easiest AOSP approach is to copy that directory tree as-is into the final image and then install thin wrappers in `/system/bin`.

## Why use `find-copy-subdir-files`

The runtime is a directory tree, not a single file. For classic product makefiles, the most practical way to embed it is:

```make
$(call find-copy-subdir-files,*,<src-dir>,<dst-dir>)
```

That avoids writing one `PRODUCT_COPY_FILES` line per file.

## Example integration flow

1. Build the runtime in Docker.
2. Copy `output/runtime/minimal/` into your AOSP tree.
3. Copy the wrapper scripts from `patches/aosp/system-bin/`.
4. Include `patches/aosp/product-python3.mk` from your product makefile.
5. Rebuild the image.

## Example product include

In your product definition:

```make
$(call inherit-product, vendor/<your-org>/python3/aosp/product-python3.mk)
```

## Notes

- The example installs the runtime under `/system/opt/python3`.
- The wrappers expose:
  - `/system/bin/python3`
  - `/system/bin/python`
  - `/system/bin/pip`
- If your product prefers `system_ext` or `vendor`, adjust the destination paths in `product-python3.mk` and the wrapper scripts.
- If the target image is read-only, embedding it in the image is cleaner than pushing it later with `adb`.
