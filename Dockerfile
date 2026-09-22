# Runs the SIMPL tests against your own src/, with no JDK or ANTLR installed.
#
#   docker build -t simpl-tests .
#   docker run --rm -v "$PWD/src:/work/src:ro" simpl-tests
#   docker run --rm -v "$PWD/src:/work/src:ro" simpl-tests type scope
#
# Your sources are mounted read-only; generated Java and .class files stay in
# the container. MAIN=name as an -e if your driver class is not called "simpl".

FROM eclipse-temurin:21-jdk

ARG ANTLR_VERSION=4.13.2
ENV ANTLR_JAR=/opt/antlr/antlr-${ANTLR_VERSION}-complete.jar

# the one download; the image is otherwise a JDK and the tests
ADD https://www.antlr.org/download/antlr-${ANTLR_VERSION}-complete.jar ${ANTLR_JAR}
RUN chmod 0644 ${ANTLR_JAR}

ENV SRC=/work/src
WORKDIR /work
COPY . /work/test

ENTRYPOINT ["/work/test/run.sh"]
