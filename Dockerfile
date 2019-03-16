ARG BUILD_IMAGE=openjdk:8

# Build image
FROM ${BUILD_IMAGE}
LABEL maintainer="ome-devel@lists.openmicroscopy.org.uk"

USER root
RUN apt-get -q update && apt-get -qy install maven \
   ant \
   git \
   python-sphinx

RUN id 1000 || useradd -u 1000 -ms /bin/bash build
COPY --chown=1000:1000 . /bio-formats-build

USER 1000
WORKDIR /bio-formats-build
RUN git submodule update --init
RUN mvn clean install -DskipSphinxTests -Dsurefire.useSystemClassLoader=false

WORKDIR /bio-formats-build/bioformats
RUN ant clean jars tools test

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.en
ENV TZ "Europe/London"

WORKDIR /bio-formats-build/bioformats/components/test-suite
ENTRYPOINT ["/usr/bin/ant", "test-automated", "-Dtestng.directory=/data", "-Dtestng.configDirectory=/config"]
