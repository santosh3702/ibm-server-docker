FROM ubuntu:16.04

LABEL maintainer "Goru Santosh Rahul <gorusantosh.rahul1@tcs.com>"

# The URL to download the MQ installer from in tar.gz format
ARG MQ_URL=http://168.61.182.56:8001/IBM_MQ_9.1.0.3_UBUNTU_X86-64.tar.gz

# The MQ packages to install
ARG MQ_PACKAGES="ibmmq-runtime ibmmq-man ibmmq-server ibmmq-java ibmmq-jre ibmmq-gskit ibmmq-web ibmmq-msg-.*"

RUN export DEBIAN_FRONTEND=noninteractive \
  # Install additional packages required by MQ, this install process and the runtime scripts
  && apt-get update -y \
  && apt-get install -y --no-install-recommends \
    bash \
    bc \
    ca-certificates \
    coreutils \
    curl \
    debianutils \
    file \
    findutils \
    gawk \
    grep \
    libc-bin \
    lsb-release \
    mount \
    passwd \
    procps \
    sed \
    tar \
    util-linux \
  # Download and extract the MQ installation files
  && export DIR_EXTRACT=/tmp/mq \
  && mkdir -p ${DIR_EXTRACT} \
  && cd ${DIR_EXTRACT} \
  && curl -LO $MQ_URL \
  && tar -zxvf ./*.tar.gz \
  # Recommended: Remove packages only needed by this script
  && apt-get purge -y \
    ca-certificates \
    curl \
  # Recommended: Remove any orphaned packages
  && apt-get autoremove -y --purge \
  # Recommended: Create the mqm user ID with a fixed UID and group, so that the file permissions work between different images
  && groupadd --system --gid 999 mqm \
  && useradd --system --uid 999 --gid mqm mqm \
  && usermod -G mqm root \
  # Find directory containing .deb files
  && export DIR_DEB=$(find ${DIR_EXTRACT} -name "*.deb" -printf "%h\n" | sort -u | head -1) \
  # Find location of mqlicense.sh
  && export MQLICENSE=$(find ${DIR_EXTRACT} -name "mqlicense.sh") \
  # Accept the MQ license
  && ${MQLICENSE} -text_only -accept \
  && echo "deb [trusted=yes] file:${DIR_DEB} ./" > /etc/apt/sources.list.d/IBM_MQ.list \
  # Install MQ using the DEB packages
  && apt-get update \
  && apt-get install -y $MQ_PACKAGES \
  # Remove 32-bit libraries from 64-bit container
  && find /opt/mqm /var/mqm -type f -exec file {} \; \
    | awk -F: '/ELF 32-bit/{print $1}' | xargs --no-run-if-empty rm -f \
  # Remove tar.gz files unpacked by RPM postinst scripts
  && find /opt/mqm -name '*.tar.gz' -delete \
  # Recommended: Set the default MQ installation (makes the MQ commands available on the PATH)
  && /opt/mqm/bin/setmqinst -p /opt/mqm -i \
  # Clean up all the downloaded files
  && rm -f /etc/apt/sources.list.d/IBM_MQ.list \
  && rm -rf ${DIR_EXTRACT} \
  # Apply any bug fixes not included in base Ubuntu or MQ image.
  # Don't upgrade everything based on Docker best practices https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/#run
  && apt-get upgrade -y sensible-utils \
  # End of bug fixes
  && rm -rf /var/lib/apt/lists/* 

COPY *.sh /usr/local/bin/
COPY *.mqsc /etc/mqm/
COPY admin.json /etc/mqm/

COPY mq-dev-config /etc/mqm/mq-dev-config

RUN chmod +x /usr/local/bin/*.sh

# Always use port 1414 (the Docker administrator can re-map ports at runtime)
# Expose port 9443 for the web console
EXPOSE 1414 9443

ENV LANG=en_US.UTF-8

ENTRYPOINT ["mq.sh"]
