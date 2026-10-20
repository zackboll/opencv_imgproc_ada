FROM debian:12
ARG ALIRE_VERSION=2.1.1
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential binutils ca-certificates curl git libopencv-dev pkg-config unzip python3 gnat-12 \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fL -o /tmp/alire.zip \
    "https://github.com/alire-project/alire/releases/download/v${ALIRE_VERSION}/alr-${ALIRE_VERSION}-bin-x86_64-linux.zip" \
    && unzip /tmp/alire.zip -d /tmp/alire \
    && install -m 0755 /tmp/alire/bin/alr /usr/local/bin/alr \
    && rm -rf /tmp/alire /tmp/alire.zip
RUN alr -n --force toolchain --select gnat_native=16.1.0 gprbuild=26.0.1