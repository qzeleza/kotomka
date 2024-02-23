FROM debian:11
#FROM ubuntu:latest

MAINTAINER	Zeleza

ARG USER="${USER}"
#ARG UID="${U_ID}"
#ARG GID="${G_ID}"
#ARG GROUP="${GROUP}"
ARG APP_NAME="${APP_NAME}"
ARG GPT_TOKEN="${GPT_TOKEN}"

ARG DEBIAN_FRONTEND=noninteractive

#   OLD Libs
#        libc6:i386 libncurses5:i386 libstdc++6:i386 \
#        build-essential subversion libncurses5-dev zlib1g-dev gawk  \
#        gcc-multilib flex git-core gettext libssl-dev \
#        rsync unzip wget file nano iputils-ping jq curl \
#        python2 python3 python3-dev python3-distutils-extra \
#&& groupadd --gid ${GID} ${USER}  \
#&& useradd --create-home --system --uid ${UID} --gid ${GID} --shell /bin/bash ${USER}  \
#chown -R ${USER}:${GROUP} ${DC_APPS_ROOT}/entware ${DC_APPS_ROOT}/${APP_NAME} \

RUN chmod 1777 /tmp \
    && dpkg --add-architecture i386  \
    && apt-get update \
    && apt-get update -qq \
    && apt-get install -y \
        ccache 	g++-multilib gcc-multilib build-essential  \
        genisoimage gosu libdw-dev libelf-dev libncurses5-dev \
        locales mc pv python python3 python3-pip qemu-utils \
	    rsync signify-openbsd subversion sudo swig \
	    unzip wget zstd nano iputils-ping jq \
    && DEBIAN_FRONTEND=noninteractive apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG=en_US.utf8

RUN pip3 install -U pip pyelftools pyOpenSSL service_identity \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && useradd -c "Kotomka Entware Builder" -m -d /home/${USER} -G sudo -s /bin/bash ${USER}

USER ${USER}
ENV HOME /home/${USER}
WORKDIR ${HOME}

ARG DC_APPS_ROOT="${HOME}${APPS_ROOT}"

RUN git clone https://github.com/Entware/Entware.git  \
    && mv Entware/ entware/ && cd ${DC_APPS_ROOT}/entware  \
    && make package/symlinks  \
    && cd /usr/local/src/ \
    && git clone https://github.com/sstephenson/bats.git \
    && cd bats && ./install.sh /usr/local \
    && mkdir -p ${DC_APPS_ROOT}/entware/package/utils/${APP_NAME}/files ${DC_APPS_ROOT}/${APP_NAME}

RUN sed -i 's|^#.*\(force_color_prompt=yes\)|\1|' ~/.bashrc \
	&& sed -i "s|u@\\\h|u@\${ARCH_BUILD}|g" ~/.bashrc \
    && ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

WORKDIR ${DC_APPS_ROOT}

