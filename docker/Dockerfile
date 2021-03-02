FROM debian:stable-slim

ENV VERSION='master'

VOLUME ["/buildroot"]
VOLUME ["/snapos"]
WORKDIR /image

# Install packages
RUN apt-get update && \
    apt-get -y install build-essential fakeroot git ncurses-dev wget bc sed file perl rsync cpio unzip python3 nano libssl-dev ca-certificates --no-install-recommends && \
    apt-get clean && \
    touch /image/.empty

COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
CMD ["make menuconfig"]
