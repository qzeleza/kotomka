FROM ubuntu:22.04
 
ARG USER="${USER}"
ARG UID="${UID}"
ARG GID="${GID}"
ARG GROUP="${GROUP}"
ARG APP_NAME="${APP_NAME}"
ARG APPS_ROOT="${APPS_ROOT}"

ENV LANG en_US.utf8

RUN chmod 1777 /tmp \
    && dpkg --add-architecture i386  \
    && groupadd --gid ${GID} ${USER}  \
    && useradd --create-home --uid ${UID} --gid ${GID} --shell /bin/bash ${USER}  \
    && apt-get update \
    && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
    && apt-get update -qq \
    && apt-get install -y \
    libc6:i386 libncurses5:i386 libstdc++6:i386 \
    build-essential subversion libncurses5-dev zlib1g-dev gawk  \
    gcc-multilib flex git-core gettext libssl-dev \
    rsync unzip wget file nano iputils-ping \
    python2 python3 python3-dev python3-distutils-extra \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR ${APPS_ROOT}
RUN rm -rf /var/lib/apt/lists/* \
    && git clone https://github.com/Entware/Entware.git  \
    && mv Entware/ entware/ && cd ${APPS_ROOT}/entware  \
    && make package/symlinks  \
    && cp `ls ${APPS_ROOT}/entware/configs/mipsel-*` .config \
    && cd /usr/local/src/ \
    && git clone https://github.com/sstephenson/bats.git \
    && cd bats && ./install.sh /usr/local \
    && mkdir -p ${APPS_ROOT}/entware/package/utils/${APP_NAME}/files ${APPS_ROOT}/${APP_NAME}

RUN chown -R ${USER}:${GROUP} ${APPS_ROOT}/entware ${APPS_ROOT}/${APP_NAME}

USER ${USER}
RUN ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa



