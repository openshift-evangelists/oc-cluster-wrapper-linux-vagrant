#!/usr/bin/env bash
#
# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"

##################################################
#
# Setting sane defaults, just in case
: ${__OS_JOURNAL_SIZE:="100M"}
: ${__OS_DOCKER_STORAGE_SIZE:="30G"}
: ${__OS_VERSION:="v1.4.1"}

# This script must be run as root
must_run_as_root(){
   [ "$UID" -ne 0 ] && echo "To run this script you need root permissions (either root or sudo)" && exit 1
}

#################################################################
OS-Setup(){
      dnf update -y
      # Install additional packages
      dnf install -y docker git bind-utils bash-completion htop; yum clean all

      # Install jq for json parsing
      curl --fail --silent --location --retry 3 \
         https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 \
         -o /usr/local/bin/jq \
         && chmod 755 /usr/local/bin/jq

      # Fail if commands have not been installed
      [ "$(which docker)" = "" ] && echo "[ERROR] Docker is not properly installed" && exit 1
      [ "$(which git)" = "" ] && echo "[ERROR] Git is not properly installed" && exit 1
      [ "$(which jq)" = "" ] && echo "[ERROR] jq is not properly installed" && exit 1

      # Update journal size so it doesn't grow forever
      sed -i -e "s/.*SystemMaxUse.*/SystemMaxUse=${__OS_JOURNAL_SIZE}/" /etc/systemd/journald.conf
      systemctl restart systemd-journald
}

DOCKER-Setup(){
      systemctl stop docker

      # Add docker capabilities to vagrant user
      groupadd docker
      usermod -aG docker vagrant

      # TODO: Find why Origin does not start in enforcing
      sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
      sudo setenforce 0
      echo "[WARN] Set SELinux to permissive for now"

      ##  Enable the internal registry and configure the Docker to allow pushing to internal OpenShift registry
      echo "[INFO] Configuring Docker for Red Hat registry and else ..."
      sed -i -e "s/^.*INSECURE_REGISTRY=.*/INSECURE_REGISTRY='--insecure-registry 172\.32\.0\.0\/16 '/" /etc/sysconfig/docker
      sed -i -e "s/^.*OPTIONS=.*/OPTIONS='--selinux-enabled --storage-opt dm\.loopdatasize=${__OS_DOCKER_STORAGE_SIZE}'/" /etc/sysconfig/docker
      # sed -i -e "s/^.*ADD_REGISTRY=.*/ADD_REGISTRY='--add-registry registry\.access\.redhat\.com'/" /etc/sysconfig/docker

      ## Disable firewall
      systemctl stop firewalld; systemctl disable firewalld
      systemctl start docker; systemctl enable docker
}

OC-CLUSTER-Setup(){
  # Validate that options are ok, and that requirements are met
  # Download release info
  curl -skL https://api.github.com/repos/openshift/origin/releases/tags/${__OS_VERSION} -o /tmp/origin-release.json
  if [[  $(cat /tmp/origin-release.json | jq '.message') == "\"Not Found\"" ]]
  then
    echo "[ERROR] Release ${__OS_VERSION} not found. Instllation will exit now" && exit 1
  else
    echo "[INFO] Release found"
  fi
  # Download the release and extract
  cat /tmp/origin-release.json | jq '.assets[].browser_download_url' | grep "client-tools" | grep "linux-64bit" | sed -e 's/^"//'  -e 's/"$//' | xargs curl -kL -o /tmp/origin.tar.gz
  [ ! -f /tmp/origin.tar.gz ] && "[ERROR] File not found" && exit 1

  mkdir -p /tmp/origin
  tar -xvzf /tmp/origin.tar.gz -C /tmp/origin

  # We use for images the same version as for release
  export __VERSION=${__OS_VERSION}

  # We copy the binaries into the /usr/local/bin
  __dir=$(find /tmp/origin -name "*origin-*")
  mv $__dir/oc /usr/local/bin
  chmod 755 /usr/local/bin/oc
  # Add bash completion
  /usr/local/bin/oc completion bash > /etc/bash_completion.d/oc.bash
}


OC-CLUTER-WRAPPER-Setup(){
  git clone https://github.com/openshift-evangelists/oc-cluster-wrapper /home/vagrant/oc-cluster-wrapper
  chown -R vagrant:vagrant /home/vagrant/oc-cluster-wrapper
  echo 'PATH=$HOME/oc-cluster-wrapper:$PATH' >> /home/vagrant/.bash_profile
  echo 'export PATH' >> /home/vagrant/.bash_profile
}

must_run_as_root

OS-Setup
DOCKER-Setup
OC-CLUSTER-Setup
OC-CLUTER-WRAPPER-Setup
