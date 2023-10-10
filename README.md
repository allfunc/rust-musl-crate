[![CircleCI](https://circleci.com/gh/allfunc/rust-musl-crate/tree/main.svg?style=svg)](https://circleci.com/gh/allfunc/rust-musl-crate/tree/main)
[![Docker Pulls](https://img.shields.io/docker/pulls/allfunc/rust-musl-crate.svg)](https://hub.docker.com/r/allfunc/rust-musl-crate)

# `rust-musl-crate`

> TODO: description

## `GIT`

-   https://github.com/allfunc/rust-musl-crate

## `Docker hub`

-   Docker Image: allfunc/rust-musl-crate
-   https://hub.docker.com/r/allfunc/rust-musl-crate

## Check open ssl platform list
-   https://www.openssl.org/policies/general-supplemental/platforms.html
-   https://wiki.openssl.org/index.php/Compilation_and_Installation#Supported_Platforms

```
 ./Configure LIST
```

### linux/amd64

-   Dockerfile

```
FROM --platform=linux/amd64 ubuntu:20.04
```

-   install-packages.sh

```
env CC=musl-gcc ./Configure no-shared no-zlib -fPIC --prefix=/usr/local/musl -DOPENSSL_NO_SECURE_MEMORY linux-x86_64 \
   && env C_INCLUDE_PATH=/usr/local/musl/include/ make depend \
   && env C_INCLUDE_PATH=/usr/local/musl/include/ make \
   && make install
```
