FROM ubuntu:latest
MAINTAINER ome-devel@lists.openmicroscopy.org.uk

RUN apt-get -q update && apt-get -qy install openjdk-8-jdk \
  maven \
  ant \
  git \
  python-sphinx \
  locales

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8

ENV LANG en_US.UTF-8 

RUN useradd -m bf

COPY . /bio-formats-build
RUN chown -R bf /bio-formats-build

USER bf
WORKDIR /bio-formats-build
RUN git submodule update --init
RUN mvn clean install -DskipSphinxTests

WORKDIR /bio-formats-build/bioformats
RUN ant clean jars tools test


ENV TZ "Europe/London"

WORKDIR /bio-formats-build/bioformats/components/test-suite
ENTRYPOINT ["/usr/bin/ant", "test-automated", "-Dtestng.directory=/opt/data", "-Dtestng.configDirectory=/opt/config"]
