FROM ubuntu:latest
 
ARG USER="${USER}"
ARG UID="${U_ID}"
ARG GID="${G_ID}"
ARG GROUP="${GROUP}"
ARG APP_NAME="${APP_NAME}"
ARG APPS_ROOT="${APPS_ROOT}"
ARG DEBIAN_FRONTEND=noninteractive

RUN chmod 1777 /tmp \
    && dpkg --add-architecture i386  \
    && groupadd --gid ${GID} ${USER}  \
    && useradd --create-home --uid ${UID} --gid ${GID} --shell /bin/bash ${USER}  \
    && apt-get update \
    && apt-get install -y locales apt-utils language-pack-ru \
    && apt-get update -qq \
    && apt-get install -y \
        libc6:i386 libncurses5:i386 libstdc++6:i386 \
        build-essential subversion libncurses5-dev zlib1g-dev gawk  \
        gcc-multilib flex git-core gettext libssl-dev \
        rsync unzip wget file nano iputils-ping iproute2 \
        python2 python3 python3-dev python3-distutils-extra \
    && DEBIAN_FRONTEND=noninteractive apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR ${APPS_ROOT}
RUN rm -rf /var/lib/apt/lists/* \
    && git clone https://github.com/Entware/Entware.git  \
    && mv Entware/ entware/ && cd ${APPS_ROOT}/entware  \
    && make package/symlinks  \
    && cd /usr/local/src/ \
    && git clone https://github.com/sstephenson/bats.git \
    && cd bats && ./install.sh /usr/local \
    && mkdir -p ${APPS_ROOT}/entware/package/utils/${APP_NAME}/files ${APPS_ROOT}/${APP_NAME}

RUN chown -R ${USER}:${GROUP} ${APPS_ROOT}/entware ${APPS_ROOT}/${APP_NAME} \
    && echo "export LANG=ru_RU.UTF-8" >> ~/.bashrc \
    && sed -i 's|^#.*\(force_color_prompt=yes\)|\1|' ~/.bashrc \
	&& sed -i "s|u@\\\h|u@\${ARCH_BUILD}|g" ~/.bashrc

USER ${USER}
RUN ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa \
    && echo "export LANG=ru_RU.UTF-8" >> ~/.bashrc \
    && sed -i 's|^#.*\(force_color_prompt=yes\)|\1|' ~/.bashrc \
	&& sed -i "s|u@\\\h|u@\${ARCH_BUILD}|g" ~/.bashrc



