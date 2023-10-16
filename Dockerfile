ARG VERSION=${VERSION:-[VERSION]}

FROM ubuntu:20.04

ARG VERSION

ENV RUSTUP_HOME=/opt/rust/rustup \
  X86_64_UNKNOWN_LINUX_MUSL_OPENSSL_DIR=/usr/local/musl/ \
  AARCH64_UNKNOWN_LINUX_MUSL_OPENSSL_DIR=/usr/local/musl/ \
  X86_64_UNKNOWN_LINUX_MUSL_OPENSSL_STATIC=1 \
  AARCH64_UNKNOWN_LINUX_MUSL_OPENSSL_STATIC=1 \
  PQ_LIB_STATIC_X86_64_UNKNOWN_LINUX_MUSL=1 \
  PQ_LIB_STATIC_AARCH64_UNKNOWN_LINUX_MUSL=1 \
  PKG_CONFIG_ALLOW_CROSS=true \
  PKG_CONFIG_ALL_STATIC=true \
  LIBZ_SYS_STATIC=1 \
  TARGET=musl \
  CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_RUSTFLAGS="-C link-arg=/opt/musl/lib/libc.a" \
  CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER="rust-lld" \
  PATH=$PATH:/home/rust/.cargo/bin:/opt/rust/cargo/bin:/opt/musl/bin:/usr/local/musl/bin


# install package
COPY ./install-packages.sh /usr/local/bin/install-packages
RUN apt-get update \
  && INSTALL_VERSION=$VERSION INSTALL_TARGETPLATFORM=$TARGETPLATFORM install-packages \
  && rm /usr/local/bin/install-packages

RUN env CARGO_HOME=/opt/rust/cargo cargo install cargo-local-install cargo-run-bin --no-default-features

# USER rust
WORKDIR /home/rust/src

COPY ./docker/sbin /usr/local/sbin
ENTRYPOINT ["/usr/local/sbin/entrypoint.sh"]
CMD ["server"]
