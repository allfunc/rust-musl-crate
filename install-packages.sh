#!/usr/bin/env sh

###
# Environment ${INSTALL_VERSION} pass from Dockerfile
###

CURL="curl ca-certificates"
BUILD_DEPS="${CURL} build-essential pkgconf cmake musl-dev musl-tools libssl-dev linux-libc-dev"

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

install_rust() {
  curl -Lk https://sh.rustup.rs \
    | env CARGO_HOME=/opt/rust/cargo \
      sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path
  env CARGO_HOME=/opt/rust/cargo \
    rustup component add rustfmt \
    && env CARGO_HOME=/opt/rust/cargo \
      rustup component add clippy \
    && env CARGO_HOME=/opt/rust/cargo \
      rustup target add x86_64-unknown-linux-musl
}

echo "# ------ Building rust  ------ #"
install_rust || exit 2

echo $(date +%Y%m%d%S)'-'$TARGETPLATFORM > /build_version

# Clean
apt-get clean autoclean \
  && apt-get autoremove --yes \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/{apt,dpkg,cache,log}/ \
  && rm -rf /tmp/* || exit 1

exit 0
