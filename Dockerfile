FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    adb \
    bash \
    bzip2 \
    build-essential \
    ca-certificates \
    curl \
    file \
    git \
    libbz2-dev \
    libffi-dev \
    liblzma-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    make \
    patchelf \
    perl \
    pkg-config \
    python3 \
    python3-venv \
    rsync \
    tar \
    unzip \
    wget \
    xz-utils \
    zlib1g-dev \
    zip \
    zstd \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["bash", "-lc", "sleep infinity"]
