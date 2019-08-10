FROM frolvlad/alpine-java:jdk8-slim

ARG CONFLUENCE_VERSION=6.15.7
# permissions
ARG CONTAINER_UID=7002
ARG CONTAINER_GID=7002
# Image Build Date By Buildsystem
ARG BUILD_DATE=undefined
# Language Settings
ARG LANG_LANGUAGE=en
ARG LANG_COUNTRY=US

# Setup useful environment variables
ENV CONF_HOME=/var/atlassian/confluence \
    CONF_INSTALL=/opt/atlassian/confluence \
    CONF_SCRIPTS=/usr/local/share/atlassian \
    MYSQL_DRIVER_VERSION=5.1.47

# Install Atlassian Confluence
RUN export CONTAINER_USER=confluence                &&  \
    export CONTAINER_GROUP=confluence               &&  \
    addgroup -g $CONTAINER_GID $CONTAINER_GROUP     &&  \
    adduser -u $CONTAINER_UID                           \
            -G $CONTAINER_GROUP                         \
            -h /home/$CONTAINER_USER                    \
            -s /bin/bash                                \
            -S $CONTAINER_USER                      

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
	git clone https://gitlab.com/rilian-la-te/musl-locales.git && \
	cd musl-locales && cmake -DLOCALE_PROFILE=OFF -DCMAKE_INSTALL_PREFIX:PATH=/usr . && make && make install && \
	cd .. && rm -r musl-locales && \
	apk del .locale_build && \
  /usr/local/bin/locale -a

# Set the lang, you can also specify it as as environment variable through docker-compose.yml
ENV LANG=${LANG_LANGUAGE}_${LANG_COUNTRY}.UTF-8 \
    LANGUAGE=${LANG_LANGUAGE}_${LANG_COUNTRY}.UTF-8 \
    # set our environment variable
    MUSL_LOCPATH="/usr/share/i18n/locales/musl"

RUN apk add --update                                    \
      bash \
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
RUN mkdir -p ${CONF_HOME} \
    && chown -R confluence:confluence ${CONF_HOME} \
    && mkdir -p ${CONF_INSTALL}/conf \
    && wget -O /tmp/atlassian-confluence-${CONFLUENCE_VERSION}.tar.gz http://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-${CONFLUENCE_VERSION}.tar.gz && \
    tar xzf /tmp/atlassian-confluence-${CONFLUENCE_VERSION}.tar.gz --strip-components=1 -C ${CONF_INSTALL} && \
    echo "confluence.home=${CONF_HOME}" > ${CONF_INSTALL}/confluence/WEB-INF/classes/confluence-init.properties && \
    # Install database drivers
    rm -f                                               \
      ${CONF_INSTALL}/lib/mysql-connector-java*.jar &&  \
    wget -O /tmp/mysql-connector-java-${MYSQL_DRIVER_VERSION}.tar.gz                                              \
      http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_DRIVER_VERSION}.tar.gz && \
    tar xzf /tmp/mysql-connector-java-${MYSQL_DRIVER_VERSION}.tar.gz                                              \
      -C /tmp && \
    cp /tmp/mysql-connector-java-${MYSQL_DRIVER_VERSION}/mysql-connector-java-${MYSQL_DRIVER_VERSION}-bin.jar     \
      ${CONF_INSTALL}/lib/mysql-connector-java-${MYSQL_DRIVER_VERSION}-bin.jar                                &&  \
    chown -R confluence:confluence ${CONF_INSTALL} && \
    # Install atlassian ssl tool
    # wget -O ${CONF_HOME}/SSLPoke.class https://confluence.atlassian.com/kb/files/779355358/779355357/1/1441897666313/SSLPoke.class && \
    wget -O /home/${CONTAINER_USER}/SSLPoke.class https://confluence.atlassian.com/kb/files/779355358/779355357/1/1441897666313/SSLPoke.class && \
    chown -R confluence:confluence /home/${CONTAINER_USER} && \
    # Fix: duplicates for package 'javax.annotation' with different versions
    rm -f                                               \
      ${CONF_INSTALL}/confluence/WEB-INF/lib/javax.annotation-api-*.jar &&  \
    # Remove obsolete packages and cleanup
    apk del wget && \
    # Clean caches and tmps
    rm -rf /var/cache/apk/*                         &&  \
    rm -rf /tmp/*                                   &&  \
    rm -rf /var/log/*

COPY imagescripts ${CONF_SCRIPTS}

RUN set -x \
    && /bin/bash ${CONF_SCRIPTS}/patch.sh *.jar ${CONF_INSTALL}/confluence/WEB-INF/

# Expose default HTTP connector port.
EXPOSE 8090 8091

USER confluence
VOLUME ["/var/atlassian/confluence"]
# Set the default working directory as the Confluence home directory.
WORKDIR ${CONF_HOME}
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
