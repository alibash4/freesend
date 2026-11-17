# FreeSend CI image: the pinned Flutter SDK plus every build dependency, so a
# pipeline neither downloads the SDK nor runs apt.
#
# Build and push with scripts/build_ci_image.sh. The image is pulled by GitLab
# CI as registry.gitlab.com/kaon2004a/freesend/ci/flutter:<version>.
#
# The Android pieces match what Flutter 3.50's Gradle plugin asks for:
# compileSdk 36, build-tools 36.0.0, NDK 28.2.13676358.
#
# Build for the host architecture only. The arm64 variant has to be built on an
# arm64 machine (GitLab's saas-linux-small-arm64 runner works); qemu emulation
# is far too slow for an Android SDK.
FROM ubuntu:24.04

ARG FLUTTER_VERSION=3.50.0
ARG FLUTTER_ROOT=/opt/flutter
ARG ANDROID_SDK_ROOT=/opt/android-sdk

ENV DEBIAN_FRONTEND=noninteractive \
    FLUTTER_ROOT=${FLUTTER_ROOT} \
    ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT} \
    ANDROID_HOME=${ANDROID_SDK_ROOT} \
    PATH=${FLUTTER_ROOT}/bin:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${PATH}

# Linux desktop build dependencies (GTK and the tray library), the Android JDK,
# and the general tools the packaging scripts use.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      unzip \
      xz-utils \
      file \
      python3 \
      clang \
      cmake \
      ninja-build \
      pkg-config \
      libgtk-3-dev \
      libayatana-appindicator3-dev \
      libblkid-dev \
      liblzma-dev \
      rpm \
      openjdk-17-jdk-headless \
 && rm -rf /var/lib/apt/lists/*

# Flutter from the official tarball. The archive keeps the ownership of the
# machine that packed it, so whitelist the directory before anything runs the
# tool -- without this, git refuses to touch the SDK's own repository.
RUN curl -fL --retry 3 -o /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && tar -xf /tmp/flutter.tar.xz -C /opt \
 && rm -f /tmp/flutter.tar.xz \
 && git config --global --add safe.directory "${FLUTTER_ROOT}"

# Android command-line tools, then the exact SDK pieces the build asks for.
# Licences are accepted up front so the first build never stalls on a prompt.
RUN curl -fL --retry 3 -o /tmp/cmdline-tools.zip \
      "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" \
 && mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools" \
 && unzip -q /tmp/cmdline-tools.zip -d /tmp \
 && mv /tmp/cmdline-tools "${ANDROID_SDK_ROOT}/cmdline-tools/latest" \
 && rm -f /tmp/cmdline-tools.zip \
 && yes | sdkmanager --licenses > /dev/null \
 && sdkmanager --install \
      "platform-tools" \
      "platforms;android-36" \
      "build-tools;36.0.0" \
      "ndk;28.2.13676358"

# Warm the SDK caches so the first CI job is not the one paying for them.
RUN flutter config --no-analytics \
 && flutter precache --universal --android \
 && flutter --version

WORKDIR /workspace
