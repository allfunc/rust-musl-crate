ARG VERSION=${VERSION:-[VERSION]}

FROM ubuntu:20.04

ARG VERSION

ENV RUSTUP_HOME=/opt/rust/rustup \
    PATH=/home/rust/.cargo/bin:/opt/rust/cargo/bin:/usr/local/musl/bin:$PATH

# install package 
COPY ./install-packages.sh /usr/local/bin/install-packages
RUN apt-get update \
  && INSTALL_VERSION=$VERSION INSTALL_TARGETPLATFORM=$TARGETPLATFORM install-packages \
  && rm /usr/local/bin/install-packages

COPY ./docker/sbin /usr/local/sbin
ENTRYPOINT ["/usr/local/sbin/entrypoint.sh"]
CMD ["server"]
