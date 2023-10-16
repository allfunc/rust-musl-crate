#!/usr/bin/env sh

###
# Environment ${INSTALL_VERSION} pass from Dockerfile
###

CURL="curl ca-certificates"
# https://crates.io/crates/mdbook-plantuml
PLANTUML_DEPS="libssl-dev pkgconf libpq-dev"
BUILD_DEPS="${CURL} ${PLANTUML_DEPS} build-essential cmake musl-dev musl-tools linux-libc-dev sudo"

echo "# ------ TARGETPLATFORM: $TARGETPLATFORM ------ #"
uname -a
export
echo
echo "###"
echo "# Will install build tool"
echo "###"
echo
echo $BUILD_DEPS
echo

DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt install -qq -y --no-install-recommends ${BUILD_DEPS}

#/* put your install code here */#
ln -s "/usr/bin/g++" "/usr/bin/musl-g++" || exit 50
if [ -z "$TARGETPLATFORM" ]; then
  TARGETPLATFORM=$(uname -m)
fi
OPENSSL_VERSION=1.1.1s
ZLIB_VERSION=1.3

install_aarch64_musl() {
  echo "# ------ Building aarch64_musl ------ #"
  mkdir -p /opt/musl
  curl -Lk "https://musl.cc/aarch64-linux-musl-native.tgz" | tar -xz -C /opt/musl --strip-components=1 || exit 51
}

install_openssl() {
  mkdir -p /usr/local/musl/include
  mkdir -p /tmp/openssl-src
  ln -s /usr/include/linux /usr/local/musl/include/linux \
    && ln -s /usr/include/x86_64-linux-gnu/asm /usr/local/musl/include/asm \
    && ln -s /usr/include/asm-generic /usr/local/musl/include/asm-generic
  short_version="$(echo "$OPENSSL_VERSION" | sed s'/[a-z]$//')"
  (curl -Lk "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz" \
    || curl -Lk "https://www.openssl.org/source/old/$short_version/openssl-$OPENSSL_VERSION.tar.gz") \
    | tar -xz -C /tmp/openssl-src --strip-components=1 \
    && cd /tmp/openssl-src

  ./Configure no-shared no-zlib -fPIC --prefix=/usr/local/musl -DOPENSSL_NO_SECURE_MEMORY $OPENSSL_PLATFORM
  env C_INCLUDE_PATH=/usr/local/musl/include/ make depend
  env C_INCLUDE_PATH=/usr/local/musl/include/ make
  make install
}

install_zlib() {
  curl -Lk "https://www.zlib.net/fossils/zlib-${ZLIB_VERSION}.tar.gz" | tar -xz -C /tmp/zlib --strip-components=1 && cd /tmp/zlib
  ./configure --static --prefix=/usr/local/mus
  make -j$(nproc)
  make -j$(nproc) install
}

install_sudo() {
  useradd rust --user-group --create-home --shell /bin/bash --groups sudo
  echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/nopasswd
  mkdir -p /home/rust/libs /home/rust/src /home/rust/.cargo
  mkdir -p /opt/cargo
  chown -R rust:rust /opt/cargo
  chown -R rust:rust /home/rust
  cat > /home/rust/.cargo/config << EOF
[build]
  # Target musl-libc by default when running Cargo.
  target = "${RUST_TARGET}"
EOF
  if [ 'linux-aarch64' = "${OPENSSL_PLATFORM}" ]; then
    cat >> /home/rust/.cargo/config << EOF
[build.env]
passthrough = [
  "RUSTFLAGS",
  "CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_RUSTFLAGS",
]
EOF
  fi
}

install_rust() {
  curl -Lk https://sh.rustup.rs \
    | env CARGO_HOME=/opt/rust/cargo \
      sh -s -- -y --default-toolchain ${INSTALL_VERSION} --profile minimal --no-modify-path
  env CARGO_HOME=/opt/rust/cargo \
    rustup component add rustfmt \
    && env CARGO_HOME=/opt/rust/cargo rustup component add clippy \
    && env CARGO_HOME=/opt/rust/cargo rustup target add ${RUST_TARGET} || exit 33
}

case "$TARGETPLATFORM" in
  aarch64 | linux/arm64)
    export CC=aarch64-linux-musl-gcc
    OPENSSL_PLATFORM="linux-aarch64"
    RUST_TARGET="aarch64-unknown-linux-musl"
    install_aarch64_musl
    ;;
  *)
    export CC=musl-gcc
    OPENSSL_PLATFORM="linux-x86_64"
    RUST_TARGET="x86_64-unknown-linux-musl"
    ;;
esac

echo "# ------ Building OpenSSL ------ #"
install_openssl || exit 5

echo "# ------ Building ZLIB ------ #"
install_zlib || exit 4

echo "# ------ Building rust  ------ #"
install_rust || exit 3
install_sudo || exit 2

echo $(date +%Y%m%d%S)'-'$TARGETPLATFORM > /build_version

# Clean
apt-get clean autoclean \
  && apt-get autoremove --yes \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/{apt,dpkg,cache,log}/ \
  && rm -rf rm -rf /opt/rust/cargo/registry/* \
  && rm -rf /tmp/* || exit 1

exit 0
