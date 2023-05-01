ARG BGMI_TAG=v4.3.9

FROM ddsderek/bgmi-all-in-one:${BGMI_TAG}

ARG ARIANG_TAG=1.3.4
ENV BGMI_VERSION=aria2 \
    ARIA2_UPDATE_TRACKERS=true \
    ARIA2_CUSTOM_TRACKER_URL= \
    ARIA2_LISTEN_PORT=6888 \
    ARIA2_RPC_PORT=6800 \
    ARIA2_RPC_SECRET=password \
    ARIA2_DISK_CACHE= \
    ARIA2_IPV6_MODE= \
    ARIA2_SPECIAL_MODE=

RUN set -ex && \
    # Aria2-Pro install
    curl --insecure -fsSL https://raw.githubusercontent.com/P3TERX/aria2-builder/master/aria2-install.sh | bash && \
    # AriaNg install
    mkdir -p ${BGMI_HOME}/downloader/aria2/ariang && \
    curl \
        -sL https://github.com/mayswind/AriaNg/releases/download/${ARIANG_TAG}/AriaNg-${ARIANG_TAG}.zip | \
        busybox unzip -qd ${BGMI_HOME}/downloader/aria2/ariang -