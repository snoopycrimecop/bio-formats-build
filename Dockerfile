ARG BUILD_IMAGE=eclipse-temurin:11-jdk-jammy
# Build image
FROM ${BUILD_IMAGE}
LABEL maintainer="ome-devel@lists.openmicroscopy.org.uk"

USER root

#RUN printf '%s\n' \
#    'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/20260419T000000Z bullseye main' \
#    'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/20260419T000000Z bullseye-security main' \
#    'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/20260419T000000Z bullseye-updates main' \
#    > /etc/apt/sources.list


RUN apt-get -q update && apt-get -qy install \
    ca-certificates \
    maven \
    ant \
    git \
    python3.11-venv \
    && update-ca-certificates


RUN echo "=== Remove emSign ECC Root CA - G3 if present ===" \
    && if keytool -list -cacerts -storepass changeit | grep -qi 'emsign_ecc_root_ca_-_g3'; then \
         keytool -delete -cacerts -storepass changeit \
           -alias "cn=emsign_ecc_root_ca_-_g3,o=emudhra_technologies_limited,ou=emsign_pki,c=in"; \
       else \
         echo "INFO: emSign ECC Root CA - G3 is already absent"; \
       fi \
    && echo "=== Verify emSign G3 is absent ===" \
    && if keytool -list -cacerts -storepass changeit | grep -qi 'emsign_ecc_root_ca_-_g3'; then \
         echo "ERROR: emSign ECC Root CA - G3 remains"; exit 1; \
       else \
         echo "PASS: emSign ECC Root CA - G3 absent"; \
       fi

RUN id 1000 || useradd -u 1000 -ms /bin/bash build
COPY --chown=1000:1000 . /bio-formats-build

USER 1000
WORKDIR /bio-formats-build
RUN git submodule update --init
RUN git submodule foreach -q --recursive 'branch="$(git config -f $toplevel/.gitmodules submodule.$name.branch)"; git switch $branch'

# RUN python3 -m pip install "pip @ https://files.pythonhosted.org/packages/3f/06/3e4420302363fbb71be3c7f35ce042f54bfca330e3e66b3a2e3c4cca579f/pip-26.2.2-py3-none-any.whl#sha256=fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70"
# RUN python3 -m pip install --upgrade certifi

RUN python3.11 -m venv /bio-formats-build/venv

RUN  /bio-formats-build/venv/bin/python3.11 -m pip install "pip @ https://files.pythonhosted.org/packages/3f/06/3e4420302363fbb71be3c7f35ce042f54bfca330e3e66b3a2e3c4cca579f/pip-26.2.2-py3-none-any.whl#sha256=fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70"
RUN /bio-formats-build/venv/bin/python3.11 -m pip install --upgrade certifi

ENV PATH="/bio-formats-build/venv/bin:$PATH"


RUN pip install -r bio-formats-documentation/requirements.txt
RUN pip install -r ome-model/requirements.txt

RUN mvn clean install -DskipSphinxTests -Dmaven.javadoc.skip=true

WORKDIR /bio-formats-build/bioformats

RUN java -version && javac -version && mvn -version

RUN ant jars tools

ENV TZ="Europe/London"

WORKDIR /bio-formats-build/bioformats/components/test-suite
ENTRYPOINT ["/usr/bin/ant", "test-automated", "-Dtestng.directory=/data", "-Dtestng.configDirectory=/config"]
