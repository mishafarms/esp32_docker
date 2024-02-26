FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN : \
  && apt-get update \
  && apt-get install -y \
    apt-utils \
    bash-completion \
    bison \
    ca-certificates \
    ccache \
    check \
    curl \
    file \
    flex \
    git \
    git-lfs \
    gperf \
    lcov \
    libbsd-dev \
    libffi-dev \
    libncurses-dev \
    libswt-gtk-4-java \
    libusb-1.0-0-dev \
    libwebkit2gtk-4.0-37 \
    make \
    ninja-build \
    npm \
    python3 \
    python3-pip \
    python3-venv \
    ruby \
    sudo \
    unzip \
    vim \
    wget \
    xz-utils \
    zip \
    && :


#RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
#RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /etc/apt/trusted.gpg.d/yarn.gpg >/dev/null
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update && apt-get install -y \
    yarn \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3 10


RUN python -m pip install --upgrade pip

# To build the image for a branch or a tag of IDF, pass --build-arg IDF_CLONE_BRANCH_OR_TAG=name.
# To build the image with a specific commit ID of IDF, pass --build-arg IDF_CHECKOUT_REF=commit-id.
# It is possibe to combine both, e.g.:
#   IDF_CLONE_BRANCH_OR_TAG=release/vX.Y
#   IDF_CHECKOUT_REF=<some commit on release/vX.Y branch>.
# Use IDF_CLONE_SHALLOW=1 to peform shallow clone (i.e. --depth=1 --shallow-submodules)
# Use IDF_INSTALL_TARGETS to install tools only for selected chip targets (CSV)

ARG IDF_CLONE_URL=https://github.com/espressif/esp-idf.git
ARG IDF_CLONE_BRANCH_OR_TAG=v5.1.2
ARG IDF_CHECKOUT_REF
ARG IDF_CLONE_SHALLOW
ARG IDF_INSTALL_TARGETS=all

ENV IDF_PATH=/opt/esp/idf
ENV IDF_TOOLS_PATH=/opt/esp

# install build essential needed for linux target apps, which is a preview target so it is installed with "all" only
RUN if [ "$IDF_INSTALL_TARGETS" = "all" ]; then \
    apt-get update \
    && apt-get install -y build-essential \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* ; \
  fi

RUN echo IDF_CHECKOUT_REF=$IDF_CHECKOUT_REF IDF_CLONE_BRANCH_OR_TAG=$IDF_CLONE_BRANCH_OR_TAG && \
    git config --global http.postBuffer 524288000 && \
    git clone --recursive --progress \
      ${IDF_CLONE_SHALLOW:+--depth=1 --shallow-submodules} \
      ${IDF_CLONE_BRANCH_OR_TAG:+-b $IDF_CLONE_BRANCH_OR_TAG} \
      $IDF_CLONE_URL $IDF_PATH && \
    if [ -n "$IDF_CHECKOUT_REF" ]; then \
      cd $IDF_PATH && \
      if [ -n "$IDF_CLONE_SHALLOW" ]; then \
        git fetch origin --depth=1 --recurse-submodules ${IDF_CHECKOUT_REF}; \
      fi && \
      git checkout $IDF_CHECKOUT_REF && \
      git submodule update --init --recursive; \
    fi

# Install all the required tools
RUN : \
  && update-ca-certificates --fresh \
  && $IDF_PATH/tools/idf_tools.py --non-interactive install required --targets=${IDF_INSTALL_TARGETS} \
  && $IDF_PATH/tools/idf_tools.py --non-interactive install cmake \
  && $IDF_PATH/tools/idf_tools.py --non-interactive install-python-env \
  && rm -rf $IDF_TOOLS_PATH/dist \
  && :

# The constraint file has been downloaded and the right Python package versions installed. No need to check and
# download this at every invocation of the container.
ENV IDF_PYTHON_CHECK_CONSTRAINTS=no

# Ccache is installed, enable it by default
ENV IDF_CCACHE_ENABLE=1

# Install QEMU runtime dependencies
RUN : \
  && apt-get update && apt-get install -y -q \
    bzip2 \
    libglib2.0-0 \
    libpixman-1-0 \
    libslirp0 \
  && rm -rf /var/lib/apt/lists/* \
  && :

# Install QEMU
ARG QEMU_VER=develop_8.0.0_20230522
ARG QEMU_RISCV32_DIST=esp-qemu-riscv32-softmmu-${QEMU_VER}-x86_64-linux-gnu.tar.bz2
ARG QEMU_RISCV32_SHA256=bc7607720ff3d7e3d39f3e1810b8795f376f4b9cf3783c8f2ed3f7f14ba74717
ARG QEMU_XTENSA_DIST=esp-qemu-xtensa-softmmu-${QEMU_VER}-x86_64-linux-gnu.tar.bz2
ARG QEMU_XTENSA_SHA256=a7e5e779fd593cb15f6d197034dc2fb427ed9165a4743e2febc6f6a47dfcc618

RUN bash -c ': \
  && wget --no-verbose https://github.com/espressif/qemu/releases/download/esp-${QEMU_VER//_/-}/${QEMU_RISCV32_DIST} \
  && echo "${QEMU_RISCV32_SHA256} *${QEMU_RISCV32_DIST}" | sha256sum --check --strict - \
  && tar -xf ${QEMU_RISCV32_DIST} -C /opt \
  && rm ${QEMU_RISCV32_DIST} \
  && wget --no-verbose https://github.com/espressif/qemu/releases/download/esp-${QEMU_VER//_/-}/${QEMU_XTENSA_DIST} \
  && echo "${QEMU_XTENSA_SHA256} *${QEMU_XTENSA_DIST}" | sha256sum --check --strict - \
  && tar -xf ${QEMU_XTENSA_DIST} -C /opt \
  && rm ${QEMU_XTENSA_DIST} \
  '
ENV PATH=/opt/qemu/bin:${PATH}

ARG GOSU_VERSION=1.17

# Install gosu
RUN dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
 && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
 && chmod 755 /usr/local/bin/gosu \
 && gosu nobody true

ARG USERNAME=esp32_user
ARG USERID=1000
ENV USERNAME=$USERNAME
ENV USERID=$USERID

RUN echo "# allow $USERNAME full permission\n\n $USERNAME ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers
RUN useradd -u USERID -d /home/$USERNAME -m -s /bin/bash $USERNAME \
    && usermod -a -G dialout $USERNAME \
    && usermod -a -G plugdev $USERNAME
RUN chgrp $USERID /home/$USERNAME
RUN chown $USERID /home/$USERNAME

RUN sed -i '/#if \[ -f \/etc\/bash_completion/,/fi/{s/^#//}' /root/.bashrc
RUN sed -i 's/^/#/' /etc/apt/apt.conf.d/docker-clean

# this gets the cache for tab completion
RUN apt update

# add some packages need by yarn
RUN apt install -y \
    gulp \
    gyp

# this will set the home directory as the current directory
WORKDIR /home/$USERNAME

# this should be done as the user

USER $USERNAME

# Install NVM
ENV NVM_DIR /home/$USERNAME/.nvm
ENV NODE_VERSION 21.6.1

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

# Set environment variables
ENV NODE_PATH $NVM_DIR/versions/node/v$NODE_VERSION/lib/node_modules
ENV PATH      $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

RUN echo "nodeLinker: node-modules" > .yarnrc.yml

# Enable corepack and set Yarn to stable version
RUN corepack enable \
    && yarn set version stable

RUN npm install -g node-gyp

USER root

# I am not installing these yet. They are for using opencd and I have not tested their use in a long time.
#COPY mishafarms.cfg /opt/esp/tools/openocd-esp32/v0.10.0-esp32-20210902/openocd-esp32/share/openocd/scripts/interface/ftdi/
#COPY esp32_devkitj_v1.cfg /opt/esp/tools/openocd-esp32/v0.10.0-esp32-20210902/openocd-esp32/share/openocd/scripts/interface/ftdi/

COPY entrypoint.sh /opt/esp/entrypoint.sh
RUN chmod +x /opt/esp/entrypoint.sh

ENTRYPOINT [ "/opt/esp/entrypoint.sh" ]
CMD [ "/bin/bash" ]
