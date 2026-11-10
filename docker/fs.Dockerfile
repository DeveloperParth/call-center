FROM debian:bookworm-slim

ARG FS_VERSION=v1.10.12
ARG FS_REPO=https://github.com/signalwire/freeswitch.git

# Pinned to the commits running in current prod EC2 (verified 2026-05-13).
# Bump these intentionally; never let them drift.
ARG LIBKS_SHA=b56807f
ARG SOFIA_SIP_SHA=0106ad0
ARG SPANDSP_SHA=7977601
# signalwire-c is not built (mod_signalwire disabled below); pinnedfor reference:
# ARG SIGNALWIRE_C_SHA=d715738



ENV DEBIAN_FRONTEND=noninteractive

# Minimum build deps for FreeSWITCH with its default module set.
RUN apt-get update && apt-get install -y --no-install-recommends \
        # build
        build-essential cmake automake autoconf libtool-bin pkg-config \
        git ca-certificates yasm \
        libssl-dev libsqlite3-dev libpcre3-dev libcurl4-openssl-dev\
        # core codecs
        libldns-dev libedit-dev libtiff-dev uuid-dev \
        libopus-dev libsndfile1-dev \
        libogg-dev libspeex-dev libspeexdsp-dev \
        # mod_av
        libavformat-dev libswscale-dev \
        # mod_lua
        liblua5.2-dev \
        # mod_pgsql
        libpq-dev \
        # mod_python3
        python3-dev python3-pip \
        # mod_shout
        libshout3-dev libmpg123-dev libmp3lame-dev \
        # mod_odbc_cdr
        unixodbc-dev \
        # mod_soundtouch
        libsoundtouch-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone everything first (cheap, parallelizable layer cache).
RUN git clone --depth 1 -b ${FS_VERSION} ${FS_REPO} /usr/src/freeswitch
RUN git clone https://github.com/signalwire/libks /usr/src/libs/libks \
    && git -C /usr/src/libs/libks checkout ${LIBKS_SHA}
RUN git clone https://github.com/freeswitch/sofia-sip /usr/src/libs/sofia-sip \
    && git -C /usr/src/libs/sofia-sip checkout ${SOFIA_SIP_SHA}
RUN git clone https://github.com/freeswitch/spandsp /usr/src/libs/spandsp \
    && git -C /usr/src/libs/spandsp checkout ${SPANDSP_SHA}

# Build SignalWire deps (order matters: libks first, then sofia-sip/spandsp).
RUN cd /usr/src/libs/libks && cmake . -DCMAKE_INSTALL_PREFIX=/usr -DWITH_LIBBACKTRACE=1 && make -j"$(nproc)" install
RUN cd /usr/src/libs/sofia-sip && ./bootstrap.sh && ./configure CFLAGS="-g -ggdb" --with-pic --with-glib=no --without-doxygen --disable-stun --prefix=/usr && make -j"$(nproc)" && make install
RUN cd /usr/src/libs/spandsp && ./bootstrap.sh && ./configure CFLAGS="-g -ggdb" --with-pic --prefix=/usr && make -j"$(nproc)" && make install
RUN ldconfig

WORKDIR /usr/src/freeswitch



RUN ./bootstrap.sh -j

# Use prod's modules.conf directly instead of sed-juggling defaults.
# Source of truth: prod EC2 container, copied here so the build is reproducible.
# To change which modules are built, edit docker/modules.conf (and add any
# required -dev packages to the apt list above).
COPY ./freeswitch/modules.conf /usr/src/freeswitch/modules.conf

# PYTHONWARNINGS=ignore silences the distutils DeprecationWarning that
# breaks FS configure's mod_python3 detection on Python 3.11+.
RUN export PYTHONWARNINGS=ignore \
    && ./configure --prefix=/usr/local/freeswitch --disable-dependency-tracking \
    && make -j"$(nproc)" \
    && make install

# Build & install the ESL Python bindings (the `import ESL` that the
# event-listener sidecar uses). Must run AFTER FS's make install sothe
# core ESL library/headers are in place.
RUN cd /usr/src/freeswitch/libs/esl \
    && make py3mod \
    && make py3mod-install

# Python deps for mod_python3 (api/app.py uses requests) and for the Python
# sidecars when they run from this same image. --break-system-packages is
# required on Debian 12 (PEP 668); container is our isolation boundary, so
# mixing pip + apt packages here is fine.
# COPY requirements.txt /tmp/requirements.txt
# RUN pip3 install --break-system-packages --no-cache-dir -r /tmp/requirements.txt \
#     && rm /tmp/requirements.txt

# Also point FS's compiled-in script_dir at the bind-mounted scripts dir, so
# tools that consult $script_directory (mod_lua, fs_cli `lua`/`luarun`, etc.)
# find scripts in the repo. Default for this build is
# /usr/local/freeswitch/share/freeswitch/scripts (autotools datadirconvention).
RUN rm -rf /usr/local/freeswitch/share/freeswitch/scripts \
    && ln -s /etc/freeswitch/scripts /usr/local/freeswitch/share/freeswitch/scripts

WORKDIR /etc/freeswitch

CMD ["/usr/local/freeswitch/bin/freeswitch", "-nf", "-nonat", \
     "-conf", "/etc/freeswitch", \
     "-log",  "/var/log/freeswitch", \
     "-run",  "/var/run/freeswitch", \
     "-db",   "/var/lib/freeswitch"]