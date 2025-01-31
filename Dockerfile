FROM jupyter/base-notebook:ubuntu-20.04
ARG ROS_PKG=ros-base
# ARG ROS_PKG=desktop-full
LABEL version="ROS-noetic-${ROS_PKG}"

SHELL ["conda", "run", "-n", "base", "/bin/bash", "-c"]

# --- Set system environment variables ---
ARG IAI_WS=/home/${NB_USER}/workspace/ros
ENV ROS_DISTRO=noetic
ENV ROS_PATH=/opt/ros/${ROS_DISTRO}
ENV ROS_ROOT=/opt/ros/noetic/share/ros
ENV ROS_PYTHON_VERSION=3
ENV DEBIAN_FRONTEND=noninteractive
ENV HOME /home/${NB_USER}
ENV ROS_PACKAGE_PATH=${IAI_WS}/src:${ROS_PATH}/share:${ROS_PATH}/stacks
ENV CMAKE_PREFIX_PATH=/home/${NB_USER}/workspace/ros/devel:${ROS_PATH}
ENV PATH=/home/jovyan/.local/bin:${ROS_PATH}/bin:/root/.local/bin:$PATH
ENV PYTHONPATH=${IAI_WS}/devel/lib/python3/dist-packages:${ROS_PATH}/lib/python3/dist-packages
ENV LD_LIBRARY_PATH=${IAI_WS}/devel/lib:${ROS_PATH}/lib:${ROS_PATH}/lib/x86_64-linux-gnu
ENV ROS_MASTER_URI=http://localhost:11311

# --- Install ros noetic and compiler packages ---
USER root
RUN apt update && apt install -y \
    curl \
    gnupg2 \
    build-essential \
    lsb-release \
    net-tools \
    xvfb \
    git \
    vim \
    htop && \
    rm -rf /var/lib/apt/lists/* && \
    apt clean

USER ${NB_USER}
# --- Install Oh-my-bash ---
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended
# --- Customize .bashrc ---
COPY --chown=${NB_USER}:users ./bashrc.sh /home/${NB_USER}/.bashrc

USER root
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add -
RUN apt update && apt install -y \
    ros-${ROS_DISTRO}-${ROS_PKG} \
    ros-${ROS_DISTRO}-tf2-tools && \
    apt clean && \
    echo "source ${ROS_PATH}/setup.bash" >> /root/.bashrc && \
    echo "source ${ROS_PATH}/setup.bash" >> /home/${NB_USER}/.bashrc

USER ${NB_USER}
# Install python packages
RUN pip install \
    autobahn \
    catkin-tools \
    cbor2 \
    cryptography==38.0.4 \
    empy \
    gnupg \
    ipywidgets \
    jupyterlab==3.6.5 \
    jupyter-resource-usage \
    jupyter-offlinenotebook \
    jupyter-server-proxy \
    jupyterlab-git \
    pymongo \
    Pillow \
    pycryptodomex \
    pyyaml==5.3.1 \
    rosdep \
    rosinstall \
    rosinstall-generator \
    rosdistro \
    simplejpeg \
    twisted \
    wstool && \
    pip cache purge

# "rosdep init" need root permission
USER root
RUN rosdep init
USER ${NB_USER}
# ---  Create an Catkin Workspace ---
RUN mkdir -p /home/${NB_USER}/workspace/ros/src
WORKDIR /home/${NB_USER}/workspace/ros
# ---  Intall ROS Webtools ---
RUN catkin init && \
    cd src && \
    wstool init && \
    wstool merge https://raw.githubusercontent.com/yxzhan/rvizweb/master/.rosinstall && \
    wstool update && \
    catkin config --extend ${ROS_PATH} && \
    rosdep update

USER root
RUN rosdep install -y --ignore-src --from-paths ./ -r && \
    rosdep fix-permissions

USER ${NB_USER}
RUN catkin build && \
    echo "source /home/${NB_USER}/workspace/ros/devel/setup.bash" >> /home/${NB_USER}/.bashrc

# --- Install developing jupyterlab extensions ---
RUN pip install \
    https://raw.githubusercontent.com/yxzhan/jlab-enhanced-cell-toolbar/main/dist/jlab-enhanced-cell-toolbar-4.0.0.tar.gz \
    https://raw.githubusercontent.com/yxzhan/jupyterlab-rviz/master/dist/jupyterlab_rviz-0.2.8.tar.gz

# --- Appy JupyterLab Settings ---
COPY --chown=${NB_USER}:users ./jupyter-settings.json /opt/conda/share/jupyter/lab/settings/overrides.json

# --- Entrypoint ---
COPY --chown=${NB_USER}:users ./entrypoint.sh /home/${NB_USER}/.local/
ENTRYPOINT ["/home/jovyan/.local/entrypoint.sh"]

WORKDIR /home/${NB_USER}/
CMD ["start-notebook.sh"]