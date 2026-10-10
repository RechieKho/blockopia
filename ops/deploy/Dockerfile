# Blockopia game server: the Voxel Browser dedicated server built from source at a pinned engine
# tag, plus this pack. Built by docker-compose.yml (context = the repository root).
ARG VB_VERSION=v0.1.5

FROM ubuntu:24.04 AS engine
ARG VB_VERSION
# VB_DISTRIBUTION=ON is how release servers are built: dev-only flags (--insecure-skip-auth) and
# the automation channel are compiled out.
ARG VB_DISTRIBUTION=ON
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential cmake ninja-build git ca-certificates python3 \
        libprotobuf-dev protobuf-compiler libssl-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "${VB_VERSION}" https://github.com/VoxelBrowser/voxel_browser.git /src
RUN cmake -S /src -B /build -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DVB_BUILD_CLIENT=OFF -DVB_BUILD_CLI=OFF -DVB_BUILD_TESTS=OFF -DVB_BUILD_EDITOR=OFF \
        -DVB_WITH_LUA=ON -DVB_WITH_NET=ON -DVB_WITH_REPLICATION=ON -DVB_WITH_COMPRESSION=ON \
        -DVB_WITH_AUTH=ON -DVB_DISTRIBUTION=${VB_DISTRIBUTION} \
    && cmake --build /build --target voxel_browser_server \
    && strip /build/voxel_browser_server

FROM ubuntu:24.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates libprotobuf32t64 libssl3t64 zlib1g rsync \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --home-dir /srv/blockopia blockopia
COPY --from=engine /build/voxel_browser_server /usr/local/bin/voxel_browser_server
# The pack as shipped; the entrypoint copies it into the data volume on every start.
COPY --chown=blockopia . /opt/blockopia
COPY --chmod=0755 ops/deploy/entrypoint.sh /usr/local/bin/blockopia-entrypoint
USER blockopia
WORKDIR /data
VOLUME /data
EXPOSE 7777/udp
ENTRYPOINT ["blockopia-entrypoint"]
