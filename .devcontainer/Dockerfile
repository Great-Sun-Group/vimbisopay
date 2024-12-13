FROM ubuntu:22.04

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Configure Flutter version
ARG FLUTTER_VERSION=stable
ENV FLUTTER_ROOT=/usr/local/flutter
ENV FLUTTER_HOME=/usr/local/flutter

# Configure Android SDK version
ENV ANDROID_SDK_ROOT=/usr/local/android-sdk
ENV ANDROID_SDK_HOME=/usr/local/android-sdk
ENV ANDROID_HOME=/usr/local/android-sdk
ENV ANDROID_SDK_TOOLS_VERSION=9477386

# Setup essential packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-11-jdk \
    wget \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone -b ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_ROOT}

# Install Android SDK
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_TOOLS_VERSION}_latest.zip && \
    unzip *tools*linux*.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools && \
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
    rm *tools*linux*.zip

# Set environment variables
ENV PATH=${PATH}:${FLUTTER_ROOT}/bin:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools

# Accept Android SDK licenses
RUN yes "y" | sdkmanager "platform-tools" "platforms;android-33" "build-tools;33.0.0"

# Pre-download Flutter artifacts
RUN flutter precache

# Verify flutter installation
RUN flutter doctor

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog
