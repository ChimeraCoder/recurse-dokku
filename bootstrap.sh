#!/bin/bash
#
# A script to bootstrap dokku.
# It expects to be run on Ubuntu 14.04 via 'sudo'
# If installing a tag higher than 0.3.13, it may install dokku via a package (so long as the package is higher than 0.3.13)
# It checks out the dokku source code from Github into ~/dokku and then runs 'make install' from dokku source.

set -eo pipefail
export DEBIAN_FRONTEND=noninteractive
export DOKKU_REPO=${DOKKU_REPO:-"https://github.com/progrium/dokku.git"}

if ! command -v apt-get &>/dev/null; then
  echo "This installation script requires apt-get. For manual installation instructions, consult http://progrium.viewdocs.io/dokku/advanced-installation ."
  exit 1
fi

apt-get update
[[ $(lsb_release -sr) == "12.04" ]] && apt-get install -qq -y python-software-properties

dokku_install_source() {
  apt-get install -qq -y git make software-properties-common
  cd /root
  if [ ! -d /root/dokku ]; then
    git clone $DOKKU_REPO /root/dokku
  fi

  cd /root/dokku
  git fetch origin
  git checkout $DOKKU_CHECKOUT
  make install
}

dokku_install_package() {
  curl --silent https://get.docker.io/gpg 2> /dev/null | apt-key add - > /dev/null 2>&1
  curl --silent https://packagecloud.io/gpg.key 2> /dev/null | apt-key add - > /dev/null 2>&1

  echo "deb http://get.docker.io/ubuntu docker main" > /etc/apt/sources.list.d/docker.list
  echo "deb https://packagecloud.io/dokku/dokku/ubuntu/ trusty main" > /etc/apt/sources.list.d/dokku.list

  sudo apt-get update > /dev/null
  sudo apt-get install -qq -y "linux-image-extra-$(uname -r)" apt-transport-https

  if [[ -n $DOKKU_CHECKOUT ]]; then
    sudo apt-get install -qq -y dokku=$DOKKU_CHECKOUT
  else
    sudo apt-get install -qq -y dokku
  fi
}

if [[ -n $DOKKU_BRANCH ]]; then
  export DOKKU_CHECKOUT="origin/$DOKKU_BRANCH"
  dokku_install_source
elif [[ -n $DOKKU_TAG ]]; then
  export DOKKU_SEMVER="${DOKKU_TAG//v}"
  major=$(echo $DOKKU_SEMVER | awk '{split($0,a,"."); print a[1]}')
  minor=$(echo $DOKKU_SEMVER | awk '{split($0,a,"."); print a[2]}')
  patch=$(echo $DOKKU_SEMVER | awk '{split($0,a,"."); print a[3]}')

  # 0.3.13 was the first version with a debian package
  if [[ "$major" -eq "0" ]] && [[ "$minor" -lt "4" ]] && [[ "$patch" -lt "13" ]]; then
    export DOKKU_CHECKOUT="$DOKKU_TAG"
    dokku_install_source
  else
    export DOKKU_CHECKOUT="$DOKKU_SEMVER"
    dokku_install_package
  fi
else
  dokku_install_package
fi
