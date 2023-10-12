#!/usr/bin/env sh

###
# Environment ${INSTALL_VERSION} pass from Dockerfile
###

CURL="curl ca-certificates"
BUILD_DEPS="${CURL} build-essential pkgconf cmake musl-dev musl-tools libssl-dev linux-libc-dev sudo"

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
OPENSSL_VERSION=1.1.1w

install_aarch64_musl() {
  mkdir /opt/musl
  curl -Lk "https://musl.cc/aarch64-linux-musl-cross.tgz" | tar -xz -C /opt/musl --strip-components=1
}

install_openssl() {
  case "$TARGETPLATFORM" in
    aarch64 | linux/arm64)
      # OPENSSL_PLATFORM="linux-armv4"
      OPENSSL_PLATFORM="linux-aarch64"
      install_aarch64_musl
      export CC=aarch64-linux-musl-gcc
      ;;
    *)
      export CC=musl-gcc
      OPENSSL_PLATFORM="linux-x86_64"
      ;;
  esac
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

install_sudo() {
  useradd rust --user-group --create-home --shell /bin/bash --groups sudo
  echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/nopasswd
  mkdir -p /home/rust/libs /home/rust/src /home/rust/.cargo
  chown -R rust:rust /home/rust
  cat > /home/rust/.cargo/config << EOF
[build]
 # Target musl-libc by default when running Cargo.
 target = "x86_64-unknown-linux-musl"
EOF
}

install_rust() {
  curl -Lk https://sh.rustup.rs \
    | env CARGO_HOME=/opt/rust/cargo \
      sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path
  env CARGO_HOME=/opt/rust/cargo \
    rustup component add rustfmt \
    && env CARGO_HOME=/opt/rust/cargo rustup component add clippy \
    && env CARGO_HOME=/opt/rust/cargo rustup target add x86_64-unknown-linux-musl
}

echo "# ------ Building OpenSSL ------ #"
install_openssl || exit 4

echo "# ------ Building rust  ------ #"
install_rust || exit 3
install_sudo || exit 2

echo $(date +%Y%m%d%S)'-'$TARGETPLATFORM > /build_version

# Clean
apt-get clean autoclean \
  && apt-get autoremove --yes \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/{apt,dpkg,cache,log}/ \
  && rm -rf /tmp/* || exit 1

exit 0
