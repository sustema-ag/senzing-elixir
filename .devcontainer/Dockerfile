ARG DECVONTAINER_OS_VERSION=bookworm
ARG SENZING_REPO_VERSION=2.0.0-1

FROM mcr.microsoft.com/devcontainers/base:$DECVONTAINER_OS_VERSION

ARG SENZING_REPO_VERSION
ENV SENZING_ACCEPT_EULA="I_ACCEPT_THE_SENZING_EULA"

# Install Senzing
RUN buildDeps='apt-transport-https' && \
  apt-get update && \
  apt-get install \
  -y \
  $buildDeps \
  --no-install-recommends && \
  apt-get install \
  -y \
  libpq-dev \
  ca-certificates \
  --no-install-recommends && \
  curl \
  -o senzing_repo.deb \
  https://senzing-production-apt.s3.amazonaws.com/senzingrepo_${SENZING_REPO_VERSION}_all.deb && \
  apt-get install \
  -y  \
  ./senzing_repo.deb && \
  rm senzing_repo.deb && \
  apt-get update && \
  apt-get install \
  -y \
  senzingapi \
  senzingdata-v5 && \
  apt-get purge \
  -y \
  --auto-remove $buildDeps

USER vscode
RUN python3 \
  /opt/senzing/g2/python/G2CreateProject.py \
  "$HOME/senzing" && \
  echo "source \"$HOME/senzing/setupEnv\"" >> ~/.bashrc && \
  echo "source \"$HOME/senzing/setupEnv\"" >> ~/.zshrc
USER root

# Erlang Requirements
RUN apt-get install \
  -y \
  build-essential autoconf m4 libncurses-dev libwxgtk3.2-dev \
  libwxgtk-webview3.2-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev \
  libssh-dev unixodbc-dev xsltproc fop libxml2-utils openjdk-17-jdk

# Elixir Requirements
RUN apt-get install \
  -y \
  inotify-tools

# ASDF
RUN apt-get update && \
  apt-get install curl git

USER vscode
RUN git clone \
  https://github.com/asdf-vm/asdf.git \
  ~/.asdf \
  --branch v0.14.0 && \
  export ASDF_DIR="$HOME/.asdf" && \
  . "$HOME/.asdf/asdf.sh" && \
  echo ". \"$HOME/.asdf/asdf.sh\"" >> ~/.bashrc && \
  echo ". \"$HOME/.asdf/completions/asdf.bash\"" >> ~/.bashrc && \
  echo ". \"$HOME/.asdf/asdf.sh\"" >> ~/.zshrc && \
  sed  -i 's/plugins=(git)/plugins=(git asdf)/g' ~/.zshrc && \
  asdf plugin add elixir && \
  asdf plugin add erlang
USER root
COPY ./asdf-post-create.sh /asdf-post-create.sh

# User Tooling
RUN apt-get install \
  -y \
  postgresql-client
COPY ./senzing-db-post-create.sh /senzing-db-post-create.sh