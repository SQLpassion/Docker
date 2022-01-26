FROM mcr.microsoft.com/mssql/server:2019-latest as builder

# switch to root to a bunch of stuff that requires elevated privs
USER root

# set the pwd and chown to the service account
WORKDIR /tmp
RUN chown mssql /tmp

# copy scripts and make bash files executable
# use copy instead of add, it's safer apparently
COPY sql /tmp/
COPY scripts /tmp/
RUN chmod +x /tmp/*.sh

# switch to user mssql or the container will fail
USER mssql

# run initial setup scripts
RUN /bin/bash /tmp/start-sqlserver.sh

LABEL org.opencontainers.image.vendor="SQLpassion"
LABEL org.opencontainers.image.title="SQLpassion"
LABEL org.opencontainers.image.url=https://www.sqlpassion.at
LABEL org.opencontainers.image.version=1.0
LABEL org.label-schema.description="SQL Server instance with some sample databases."
LABEL org.opencontainers.image.authors="Klaus Aschenbrenner <klaus.aschenbrenner@sqlpassion.at>"