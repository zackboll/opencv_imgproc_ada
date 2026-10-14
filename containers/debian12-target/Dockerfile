FROM debian:12@sha256:813017f3d62be4b5891a7acca6a01bdcd4b8513daa81b1ab99d3a50385b26931
# The construction script records repository/package identities. No Core install.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates python3 pkg-config binutils g++-aarch64-linux-gnu \
    gnat-12-aarch64-linux-gnu