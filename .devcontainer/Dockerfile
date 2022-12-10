# Copyright (C) 2019-2022 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
FROM ros:foxy-ros-base

ARG USERNAME=user-name-goes-here
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    libboost-all-dev \
    python3-pip \
    ros-foxy-async-web-server-cpp \
    ros-foxy-image-transport \
    ros-foxy-compressed-image-transport \
    ros-foxy-imu-tools \
    ros-foxy-tf-transformations \
    ros-foxy-cv-bridge \
    ros-foxy-robot-localization \    
    ros-foxy-rqt-console \
    ros-foxy-rqt-graph \
    ros-foxy-pybind11-vendor \
    ros-foxy-test-msgs \
    libjsoncpp-dev \
    v4l-utils \
    ffmpeg \
    sudo \
    curl

ARG build_id=2021.1.110
# Install full package
RUN curl -o GPG-PUB-KEY-INTEL-OPENVINO-2021 https://apt.repos.intel.com/openvino/2021/GPG-PUB-KEY-INTEL-OPENVINO-2021 && \
    apt-key add GPG-PUB-KEY-INTEL-OPENVINO-2021 && \
    echo "deb https://apt.repos.intel.com/openvino/2021 all main" | tee - a /etc/apt/sources.list.d/intel-openvino-2021.list && \
    apt-get update && apt-get install -y --no-install-recommends intel-openvino-dev-ubuntu20-"${build_id}" && \
    /opt/intel/openvino_"${build_id}"/deployment_tools/model_optimizer/install_prerequisites/install_prerequisites.sh tf && \
    ln --symbolic /opt/intel/openvino_"${build_id}"/ /opt/intel/openvino

RUN pip3 install -U smbus2 pillow transforms3d autopep8 opencv-python pyserial

# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && usermod -a -G audio $USERNAME \
    && usermod -a -G video $USERNAME \
    && groupadd --gid 136 i2c \
    && usermod -a -G i2c $USERNAME \
    && usermod -a -G dialout $USERNAME

# Persist history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && mkdir /commandhistory \
    && touch /commandhistory/.bash_history \
    && chown -R $USERNAME /commandhistory \
    && echo $SNIPPET >> "/home/$USERNAME/.bashrc"

ENTRYPOINT ["/bin/bash", "source /opt/ros/foxy/setup.bash"]