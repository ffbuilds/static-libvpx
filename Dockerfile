
# bump: libvpx /VPX_VERSION=([\d.]+)/ https://github.com/webmproject/libvpx.git|*
# bump: libvpx after ./hashupdate Dockerfile VPX $LATEST
# bump: libvpx link "CHANGELOG" https://github.com/webmproject/libvpx/blob/master/CHANGELOG
# bump: libvpx link "Source diff $CURRENT..$LATEST" https://github.com/webmproject/libvpx/compare/v$CURRENT..v$LATEST
ARG VPX_VERSION=1.12.0
ARG VPX_URL="https://github.com/webmproject/libvpx/archive/v$VPX_VERSION.tar.gz"
ARG VPX_SHA256=f1acc15d0fd0cb431f4bf6eac32d5e932e40ea1186fe78e074254d6d003957bb

# bump: alpine /FROM alpine:([\d.]+)/ docker:alpine|^3
# bump: alpine link "Release notes" https://alpinelinux.org/posts/Alpine-$LATEST-released.html
FROM alpine:3.16.2 AS base

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
WORKDIR /tmp/libvpx
RUN \
  apk add --no-cache --virtual build \
    build-base diffutils perl nasm yasm && \
  ./configure --enable-static --enable-vp9-highbitdepth --disable-shared --disable-unit-tests --disable-examples && \
  make -j$(nproc) install && \
  apk del build

FROM scratch
ARG VPX_VERSION
COPY --from=build /usr/local/lib/pkgconfig/vpx.pc /usr/local/lib/pkgconfig/vpx.pc
COPY --from=build /usr/local/lib/libvpx.a /usr/local/lib/libvpx.a
COPY --from=build /usr/local/include/vpx/ /usr/local/include/vpx/
