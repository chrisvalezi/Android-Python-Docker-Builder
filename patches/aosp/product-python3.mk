# Example product snippet for embedding the prebuilt Android Python runtime
# into an AOSP-based image.
#
# Expected source tree:
# vendor/<your-org>/python3/
# ├── runtime/minimal/...
# └── aosp/
#     ├── product-python3.mk
#     └── system-bin/{python3,python,pip}

LOCAL_PATH := $(call my-dir)
PYTHON3_PREBUILT_ROOT := $(LOCAL_PATH)/../runtime/minimal
PYTHON3_INSTALL_ROOT := $(TARGET_COPY_OUT_SYSTEM)/opt/python3

PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,${PYTHON3_PREBUILT_ROOT},${PYTHON3_INSTALL_ROOT}) \
    $(LOCAL_PATH)/system-bin/python3:$(TARGET_COPY_OUT_SYSTEM)/bin/python3 \
    $(LOCAL_PATH)/system-bin/python:$(TARGET_COPY_OUT_SYSTEM)/bin/python \
    $(LOCAL_PATH)/system-bin/pip:$(TARGET_COPY_OUT_SYSTEM)/bin/pip

