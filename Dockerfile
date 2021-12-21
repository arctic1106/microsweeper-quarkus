FROM registry.access.redhat.com/ubi8/openjdk-11:1.10 AS build

WORKDIR /opt/build

COPY pom.xml ./
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean compile package -DskipTests

FROM registry.access.redhat.com/ubi8/ubi-minimal:8.4 

ARG JAVA_PACKAGE=java-11-openjdk-headless
ARG RUN_JAVA_VERSION=1.3.8
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en'
# Install java, maven, and the run-java script
# Also set up permissions for user `1001`
RUN microdnf install curl ca-certificates ${JAVA_PACKAGE} \
    && microdnf update \
    && microdnf clean all \
    && mkdir /deployments \
    && chown 1001 /deployments \
    && chmod "g+rwX" /deployments \
    && chown 1001:root /deployments \
    && curl https://repo1.maven.org/maven2/io/fabric8/run-java-sh/${RUN_JAVA_VERSION}/run-java-sh-${RUN_JAVA_VERSION}-sh.sh -o /deployments/run-java.sh \
    && chown 1001 /deployments/run-java.sh \
    && chmod 540 /deployments/run-java.sh \
    && echo "securerandom.source=file:/dev/urandom" >> /etc/alternatives/jre/conf/security/java.security

# Configure the JAVA_OPTIONS, you can add -XshowSettings:vm to also display the heap size.
ENV JAVA_OPTIONS="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"
# We make four distinct layers so if there are application changes the library layers can be re-used

COPY --from=build --chown=1001 /opt/build/target/quarkus-app/lib/ /deployments/lib/
COPY --from=build --chown=1001 /opt/build/target/quarkus-app/*.jar /deployments/
COPY --from=build --chown=1001 /opt/build/target/quarkus-app/app/ /deployments/app/
COPY --from=build --chown=1001 /opt/build/target/quarkus-app/quarkus/ /deployments/quarkus/

EXPOSE 8080
USER 1001

ENTRYPOINT [ "/deployments/run-java.sh" ]

