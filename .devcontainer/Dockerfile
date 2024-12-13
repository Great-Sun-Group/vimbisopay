FROM ubuntu:22.04

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Configure apt and install packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    apt-utils \
    git \
    curl \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-17-jdk \
    wget \
    xauth \
    libpulse0 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxi6 \
    libxtst6 \
    libnss3 \
    libcups2 \
    libxss1 \
    libxrandr2 \
    libasound2 \
    libatk1.0-0 \
    libgtk-3-0 \
    libgdk-pixbuf2.0-0 \
    ninja-build \
    pkg-config \
    cmake \
    make \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog

# Setup Android SDK with minimal components needed
ENV ANDROID_SDK_ROOT /usr/local/android-sdk
ENV ANDROID_HOME /usr/local/android-sdk
ENV PATH ${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools

RUN mkdir -p ${ANDROID_SDK_ROOT} \
    && cd ${ANDROID_SDK_ROOT} \
    && curl -C - --output commandlinetools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
    && unzip commandlinetools.zip \
    && rm commandlinetools.zip \
    && mkdir -p cmdline-tools/latest \
    && mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true \
    && cd cmdline-tools/latest/bin \
    && yes | ./sdkmanager --licenses \
    && ./sdkmanager --update \
    && ./sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# Setup Flutter
ENV FLUTTER_HOME /usr/local/flutter
ENV PATH ${PATH}:${FLUTTER_HOME}/bin

# Clone Flutter stable channel
RUN git clone https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && cd ${FLUTTER_HOME} \
    && git checkout stable

# Create vscode user
RUN useradd -ms /bin/bash vscode

# Set proper ownership
RUN chown -R vscode:vscode ${FLUTTER_HOME}
RUN chown -R vscode:vscode ${ANDROID_SDK_ROOT}

# Switch to non-root user
USER vscode

# Configure Git for the vscode user
RUN git config --global --add safe.directory ${FLUTTER_HOME}

# Update Flutter and configure
RUN flutter upgrade && \
    flutter config --no-analytics && \
    flutter config --enable-web && \
    flutter doctor

# Verify installation
RUN flutter --version
