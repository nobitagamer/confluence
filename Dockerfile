FROM frolvlad/alpine-java:jdk8-slim

#     ______            ______
#    / ____/___  ____  / __/ /_  _____  ____  ________
#   / /   / __ \/ __ \/ /_/ / / / / _ \/ __ \/ ___/ _ \
#  / /___/ /_/ / / / / __/ / /_/ /  __/ / / / /__/  __/
#  \____/\____/_/ /_/_/ /_/\__,_/\___/_/ /_/\___/\___/

ARG CONFLUENCE_VERSION=6.15.7
ARG DOCKERIZE_VERSION=v0.6.1
ARG MYSQL_DRIVER_VERSION=5.1.48
ARG POSTGRESQL_DRIVER_VERSION=42.2.6

# permissions
ARG CONTAINER_UID=7002
ARG CONTAINER_GID=7002
# Image Build Date By Buildsystem
ARG BUILD_DATE=undefined
# Language Settings
ARG LANG_LANGUAGE=en
ARG LANG_COUNTRY=US

# Setup useful environment variables
ENV CONTAINER_USER=confluence                     \
    CONTAINER_GROUP=confluence                    \
    CONFLUENCE_SCRIPTS=/usr/local/share/atlassian \
    CONFLUENCE_HOME=/var/atlassian/confluence     \
    CONFLUENCE_INSTALL=/opt/atlassian/confluence  \
    CONFLUENCE_LOGS_DIR=/opt/atlassian/confluence/logs

# Install Atlassian Confluence
RUN set -x \
    && addgroup -g $CONTAINER_GID $CONTAINER_GROUP      \
    && adduser -u $CONTAINER_UID                        \
            -h /home/$CONTAINER_USER                    \
            -S -s /bin/bash                             \
            -G $CONTAINER_GROUP                         \
            $CONTAINER_USER                      

# Alpine Install language pack
# install libintl
# then install dev dependencies for musl-locales
# clone the sources
# build and install musl-locales
# remove sources and compile artifacts
# lastly remove dev dependencies again
# Test if locales work: docker run <image> sh -c 'date && LC_ALL=de_DE.UTF-8 date'
RUN apk --no-cache add libintl && \
	apk --no-cache --virtual .locale_build add cmake make musl-dev gcc gettext-dev git && \
	git clone https://gitlab.com/rilian-la-te/musl-locales.git/ && \
	cd musl-locales && cmake -DLOCALE_PROFILE=OFF -DCMAKE_INSTALL_PREFIX:PATH=/usr . && make && make install && \
	cd .. && rm -r musl-locales && \
	apk del .locale_build

# Set the lang, you can also specify it as as environment variable through docker-compose.yml
ENV LANG=${LANG_LANGUAGE}_${LANG_COUNTRY}.UTF-8 \
    LANGUAGE=${LANG_LANGUAGE}_${LANG_COUNTRY}.UTF-8 \
    # set our environment variable
    MUSL_LOCPATH="/usr/share/i18n/locales/musl"

RUN apk add --update                                    \
      bash                                              \
      tini                                              \
      ca-certificates                                   \
      gzip                                              \
      curl                                              \
      tar                                               \
      xmlstarlet                                        \
      msttcorefonts-installer                           \
      ttf-dejavu					\
      fontconfig                                        \
      ghostscript					\
      graphviz                                          \
      motif						\
      wget                                          &&  \
    # Installing true type fonts
    update-ms-fonts                                 && \
    fc-cache -f                                     && \
    # Non-Alpine: Setting Locale
    # /usr/glibc-compat/bin/localedef -i ${LANG_LANGUAGE}_${LANG_COUNTRY} -f UTF-8 ${LANG_LANGUAGE}_${LANG_COUNTRY}.UTF-8 && \
    # Adding letsencrypt-ca to truststore
    export KEYSTORE=$JAVA_HOME/jre/lib/security/cacerts && \
    wget -P /tmp/ https://letsencrypt.org/certs/letsencryptauthorityx1.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/letsencryptauthorityx2.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/lets-encrypt-x1-cross-signed.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/lets-encrypt-x2-cross-signed.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/lets-encrypt-x4-cross-signed.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias isrgrootx1 -file /tmp/letsencryptauthorityx1.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias isrgrootx2 -file /tmp/letsencryptauthorityx2.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias letsencryptauthorityx1 -file /tmp/lets-encrypt-x1-cross-signed.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias letsencryptauthorityx2 -file /tmp/lets-encrypt-x2-cross-signed.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias letsencryptauthorityx3 -file /tmp/lets-encrypt-x3-cross-signed.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias letsencryptauthorityx4 -file /tmp/lets-encrypt-x4-cross-signed.der

# Installing Confluence
RUN mkdir -p ${CONFLUENCE_HOME} \
    && chown -R "${CONTAINER_USER}":"${CONTAINER_GROUP}" ${CONFLUENCE_HOME} \
    && mkdir -p ${CONFLUENCE_INSTALL}/conf && \
    if ! wget -q "https://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-${CONFLUENCE_VERSION}.tar.gz" -P "/tmp/"; then \
      echo >&2 "Error: Failed to download Confluence binary"; \
      exit 1; \
    fi && \
    tar xzf /tmp/atlassian-confluence-${CONFLUENCE_VERSION}.tar.gz --strip-components=1 --no-same-owner -C ${CONFLUENCE_INSTALL} && \
    if ! wget -q "https://jdbc.postgresql.org/download/postgresql-${POSTGRESQL_DRIVER_VERSION}.jar" -P "${CONFLUENCE_INSTALL}/lib/"; then \
      echo >&2 "Error: Failed to download Postgresql driver"; \
      exit 1; \
    fi && \
    echo "confluence.home=${CONFLUENCE_HOME}" > ${CONFLUENCE_INSTALL}/confluence/WEB-INF/classes/confluence-init.properties \
    && xmlstarlet              ed --inplace \
        --delete               "Server/@debug" \
        --delete               "Server/Service/Connector/@debug" \
        --delete               "Server/Service/Connector/@useURIValidationHack" \
        --delete               "Server/Service/Connector/@minProcessors" \
        --delete               "Server/Service/Connector/@maxProcessors" \
        --delete               "Server/Service/Engine/@debug" \
        --delete               "Server/Service/Engine/Host/@debug" \
        --delete               "Server/Service/Engine/Host/Context/@debug" \
                                "${CONFLUENCE_INSTALL}/conf/server.xml" \
    && touch -d "@0"           "${CONFLUENCE_INSTALL}/conf/server.xml" \
    # Install database drivers
    && rm -f ${CONFLUENCE_INSTALL}/lib/mysql-connector-java*.jar &&  \
    curl -Ls "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_DRIVER_VERSION}.tar.gz" | tar -xz --directory "${CONFLUENCE_INSTALL}/lib" --strip-components=1 --no-same-owner "mysql-connector-java-${MYSQL_DRIVER_VERSION}/mysql-connector-java-${MYSQL_DRIVER_VERSION}-bin.jar" && \
    # wget -O /tmp/mysql-connector-java-${MYSQL_DRIVER_VERSION}.tar.gz                                              \
    #   http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_DRIVER_VERSION}.tar.gz && \
    # tar xzf /tmp/mysql-connector-java-${MYSQL_DRIVER_VERSION}.tar.gz                                              \
    #   -C /tmp && \
    # cp /tmp/mysql-connector-java-${MYSQL_DRIVER_VERSION}/mysql-connector-java-${MYSQL_DRIVER_VERSION}-bin.jar     \
    #   ${CONFLUENCE_INSTALL}/lib/mysql-connector-java-${MYSQL_DRIVER_VERSION}-bin.jar                                &&  \
    chown -R "${CONTAINER_USER}":"${CONTAINER_GROUP}" "${CONFLUENCE_INSTALL}" && \
    chmod -R 700 "${CONFLUENCE_INSTALL}/logs" && \
    chmod -R 700 "${CONFLUENCE_INSTALL}/temp" && \
    chmod -R 700 "${CONFLUENCE_INSTALL}/work" && \
    chmod -R 700 "${CONFLUENCE_INSTALL}/conf" && \
    # Install dockerize
    wget -O /tmp/dockerize.tar.gz https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz && \
    tar -C /usr/local/bin -xzvf /tmp/dockerize.tar.gz && \
    # Install atlassian ssl tool
    # wget -O ${CONFLUENCE_HOME}/SSLPoke.class https://confluence.atlassian.com/kb/files/779355358/779355357/1/1441897666313/SSLPoke.class && \
    wget -O /home/${CONTAINER_USER}/SSLPoke.class https://confluence.atlassian.com/kb/files/779355358/779355357/1/1441897666313/SSLPoke.class && \
    chown -R "${CONTAINER_USER}":"${CONTAINER_GROUP}" /home/${CONTAINER_USER} && \
    # Fix: duplicates for package 'javax.annotation' with different versions
    rm -f                                               \
      ${CONFLUENCE_INSTALL}/confluence/WEB-INF/lib/javax.annotation-api-*.jar &&  \
    # Remove obsolete packages and cleanup
    apk del wget && \
    # Clean caches and tmps
    rm -rf /var/cache/apk/*                         &&  \
    rm -rf /tmp/*                                   &&  \
    rm -rf /var/log/*

COPY imagescripts ${CONFLUENCE_SCRIPTS}
COPY imagescripts/dockerwait.sh /usr/bin/dockerwait

# add healthcheck script
COPY docker-healthcheck.sh /
RUN chmod 755 /docker-healthcheck.sh

RUN set -x \
    && /bin/bash ${CONFLUENCE_SCRIPTS}/patch.sh *.jar ${CONFLUENCE_INSTALL}/confluence/WEB-INF/

# Expose default HTTP connector port.
EXPOSE 8090 8091

# Switch from root
USER ${CONTAINER_USER}:${CONTAINER_GROUP}

# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME ["${CONFLUENCE_HOME}", "${CONFLUENCE_LOGS_DIR}"]

# Set the default working directory as the Confluence home directory.
WORKDIR ${CONFLUENCE_HOME}

# add launch script
COPY docker-entrypoint.sh /home/confluence/docker-entrypoint.sh

ENTRYPOINT ["/sbin/tini","--","/home/confluence/docker-entrypoint.sh"]
CMD ["confluence"]

# Image Metadata
LABEL com.blacklabelops.application.confluence.version=$CONFLUENCE_VERSION \
      com.blacklabelops.application.confluence.setting.language=$LANG_LANGUAGE \
      com.blacklabelops.application.confluence.setting.country=$LANG_COUNTRY \
      com.blacklabelops.application.confluence.userid=$CONTAINER_UID \
      com.blacklabelops.application.confluence.groupid=$CONTAINER_GID \
      com.blacklabelops.application.version.jdbc-mysql=$MYSQL_DRIVER_VERSION

# Metadata
# Image Build Date By Buildsystem
ARG BUILD_DATE=undefined
ARG VCS_REF
ARG VERSION
LABEL maintainer="Nguyen Khac Trieu <trieunk@yahoo.com>" \
    org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.name="Confluence - Alpine" \
    org.label-schema.description="Provides a Docker image for Confluence on Alpine Linux." \
    org.label-schema.url="https://trieunk.info/" \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url="https://github.com/nobitagamer/confluence-blacklabelops" \
    org.label-schema.vendor="Trieunk" \
    org.label-schema.version=$VERSION \
    org.label-schema.schema-version="1.0"
