FROM debian:stable-slim

ENV BUILDROOT_VERSION='master'
ENV SNAPOS_VERSION='master'

VOLUME ["/buildroot","/snapos","/ccache","/download"]

# Install packages
RUN apt-get update && \
    apt-get -y install build-essential fakeroot git ncurses-dev wget bc sed file perl rsync cpio unzip python3 nano libssl-dev ca-certificates --no-install-recommends && \
    apt-get clean
# Make /image and touch a file there so we can see if it's mounted
RUN mkdir /image && touch /image/.snapos-empty

COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
CMD ["help"]
