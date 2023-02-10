# syntax=docker/dockerfile:1

# bump: libvpx /VPX_VERSION=([\d.]+)/ https://github.com/webmproject/libvpx.git|*
# bump: libvpx after ./hashupdate Dockerfile VPX $LATEST
# bump: libvpx link "CHANGELOG" https://github.com/webmproject/libvpx/blob/master/CHANGELOG
# bump: libvpx link "Source diff $CURRENT..$LATEST" https://github.com/webmproject/libvpx/compare/v$CURRENT..v$LATEST
ARG VPX_VERSION=1.13.0
ARG VPX_URL="https://github.com/webmproject/libvpx/archive/v$VPX_VERSION.tar.gz"
ARG VPX_SHA256=cb2a393c9c1fae7aba76b950bb0ad393ba105409fe1a147ccd61b0aaa1501066

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG VPX_URL
ARG VPX_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O libvpx.tar.gz "$VPX_URL" && \
  echo "$VPX_SHA256  libvpx.tar.gz" | sha256sum --status -c - && \
  mkdir libvpx && \
  tar xf libvpx.tar.gz -C libvpx --strip-components=1 && \
  rm libvpx.tar.gz && \
  apk del download

FROM base AS build 
COPY --from=download /tmp/libvpx/ /tmp/libvpx/
ARG TARGETPLATFORM
WORKDIR /tmp/libvpx
RUN \
  case ${TARGETPLATFORM} in \
    linux/arm/v*) \
      # Fake it 'til we make it
      mkdir -p /usr/local/lib/pkgconfig/ && \
      touch /usr/local/lib/pkgconfig/vpx.pc && \
      touch /usr/local/lib/libvpx.a && \
      mkdir -p /usr/local/include/vpx/ && \
      exit 0 \
    ;; \
  esac && \
  apk add --no-cache --virtual build \
    build-base diffutils perl nasm yasm pkgconf && \
  ./configure --enable-static --enable-vp9-highbitdepth --disable-shared --disable-unit-tests --disable-examples && \
  make -j$(nproc) install && \
  # Sanity tests
  pkg-config --exists --modversion --path vpx && \
  ar -t /usr/local/lib/libvpx.a && \
  readelf -h /usr/local/lib/libvpx.a && \
  # Cleanup
  apk del build

FROM scratch
ARG VPX_VERSION
COPY --from=build /usr/local/lib/pkgconfig/vpx.pc /usr/local/lib/pkgconfig/vpx.pc
COPY --from=build /usr/local/lib/libvpx.a /usr/local/lib/libvpx.a
COPY --from=build /usr/local/include/vpx/ /usr/local/include/vpx/
