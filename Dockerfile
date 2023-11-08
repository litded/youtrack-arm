FROM balenalib/raspberry-pi-alpine-openjdk:latest

RUN apk update && apk add --no-cache bash fontconfig

MAINTAINER Ivan Iv <l@itded.ru>

ARG DIST_VERSION

ENV DIST_VERSION=${DIST_VERSION:-2099.99.65534}

WORKDIR /

ARG USER_UID=13001
ARG GROUP_GID=13001
ARG UGNAME=jetbrains

RUN addgroup --system --gid ${GROUP_GID} ${UGNAME}

RUN adduser --system --disabled-password --home /home/${UGNAME} \
    --uid ${USER_UID} --ingroup ${UGNAME} ${UGNAME}

COPY ./youtrack/ /opt/youtrack/

COPY ./*.sh /

COPY ./stop.sh /usr/bin/stop

RUN sed -i -e 's_<type>ZIP</type>_<type>DOCKER</type>_g' /opt/youtrack/internal/conf/installation.xml && \
    sed -i -e 's_\(<type>DOCKER</type>\)_\1\n  <installationPort>8080</installationPort>_g' /opt/youtrack/internal/conf/installation.xml && \
    mkdir -p /opt/youtrack/conf/internal && touch /opt/youtrack/conf/internal/inside.container.conf.marker && chmod 755 /run.sh && \
    chmod 755 /usr/bin/stop && chown jetbrains:jetbrains /run.sh && chown jetbrains:jetbrains /usr/bin/stop && \
    mkdir -m 0750 /opt/youtrack/logs /opt/youtrack/data /opt/youtrack/backups /opt/youtrack/temp /not-mapped-to-volume-dir && \
    chown -R jetbrains:jetbrains /opt/youtrack/logs /opt/youtrack/data /opt/youtrack/backups /opt/youtrack/temp /not-mapped-to-volume-dir /opt/youtrack/conf  && \
    chown jetbrains:jetbrains /opt/youtrack 

ENV JAVA_HOME=/opt/youtrack/internal/java/linux-x64

EXPOSE 8080

USER jetbrains

VOLUME [/opt/youtrack/logs /opt/youtrack/conf /opt/youtrack/data /opt/youtrack/backups]

ENTRYPOINT ["/bin/bash", "/run.sh"]