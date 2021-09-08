FROM debian:buster-slim AS base

LABEL maintainer="tfontaine@troyfontaine.com"
ARG PUID=1000

ENV USER="steam"
ENV HOMEDIR "/home/${USER}"
ENV STEAMCMDDIR "${HOMEDIR}/steamcmd"

RUN set -x \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    --no-install-suggests \
    lib32stdc++6=8.3.0-6 \
    lib32gcc1=1:8.3.0-6 \
    wget=1.20.1-1.1 \
    ca-certificates=20200601~deb10u2 \
    nano=3.2-3 \
    libsdl2-2.0-0:i386=2.0.9+dfsg1-1 \
    curl=7.64.0-4+deb10u2 \
    gdb=8.2.1-2+b3 \
    libtinfo5:i386=6.1+20181013-2+deb10u2 \
    libncurses5:i386=6.1+20181013-2+deb10u2 \
    libcurl3-gnutls:i386=7.64.0-4+deb10u2 \
    locales=2.28-10 \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && useradd -l -u "${PUID}" -m "${USER}"\
    && apt-get clean autoclean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

FROM base as steamcmd

USER steam

ENV USER="steam"
ENV HOMEDIR "/home/${USER}"
ENV STEAMCMDDIR "${HOMEDIR}/steamcmd"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN echo "${STEAMCMDDIR}" \
    && mkdir -p "${STEAMCMDDIR}" \
    && wget -qO- 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz' | tar xvzf - -C "${STEAMCMDDIR}" \
    && "./${STEAMCMDDIR}/steamcmd.sh" +quit \
    && mkdir -p "${HOMEDIR}/.steam/sdk32"

USER root

RUN ln -s "${STEAMCMDDIR}/linux32/steamclient.so" \
    "${HOMEDIR}/.steam/sdk32/steamclient.so" \
    && ln -s "${STEAMCMDDIR}/linux32/steamcmd" \
    "${STEAMCMDDIR}/linux32/steam" \
    && ln -s "${STEAMCMDDIR}/steamcmd.sh" \
    "${STEAMCMDDIR}/steam.sh" \
    && ln -s "${STEAMCMDDIR}/linux32/steamclient.so" \
    "/usr/lib/i386-linux-gnu/steamclient.so" \
    && ln -s "${STEAMCMDDIR}/linux64/steamclient.so" \
    "/usr/lib/x86_64-linux-gnu/steamclient.so" \
    && chown steam:steam ${STEAMCMDDIR}/* \
    && apt-get remove --purge -y \
    wget

USER steam

WORKDIR /home/steam/steamcmd

VOLUME /home/steam/steamcmd

# Base image that runs as the user steam
#FROM cm2network/steamcmd:steam
FROM steamcmd

LABEL maintainer "tfontaine@troyfontaine.com"

# We have to split this out as for some unknown
# reason, STEAM_APP doesn't resolve unless passed in separately
ENV HOMEDIR="/home/steam"

ARG STEAM_APP="hl2mp"

ENV STEAM_APP_CFG_NAME="hl2mp" \
    STEAM_APP_ID="232370" \
    STEAM_CMD_DIR="${HOMEDIR}/steamcmd" \
    STEAM_APP_DIR="${HOMEDIR}/${STEAM_APP}-dedicated"

ENV STEAM_APP_CFG_DIR="${STEAM_APP_DIR}/${STEAM_APP_CFG_NAME}/cfg" \
    SRCDS_PORT="27015" \
    SRCDS_TV_PORT="27020" \
    SRCDS_NET_PUBLIC_ADDRESS="0" \
    SRCDS_IP="0" \
    SRCDS_MAXPLAYERS="8" \
    SRCDS_RCONPW="changeme" \
    SRCDS_STARTMAP="dm_overwatch" \
    SRCDS_REGION="255" \
    SRCDS_HOSTNAME="New \"${STEAM_APP}\" Server"

RUN mkdir -p "${STEAM_APP_DIR}" \
    && ./steamcmd.sh +login anonymous +force_install_dir \
    "${STEAM_APP_DIR}" +app_update "${STEAM_APP_ID}" +quit

COPY --chown=steam:steam --chmod=755 config/* "${STEAM_APP_CFG_DIR}/"

COPY --chown=steam:steam hl2mp_update.txt "${HOMEDIR}/"

COPY --chown=steam:steam --chmod=700 docker-entry.sh "${HOMEDIR}/"

WORKDIR "${HOMEDIR}"

EXPOSE 27015/tcp 27015/udp 27020/udp

CMD ["bash", "docker-entry.sh"]
