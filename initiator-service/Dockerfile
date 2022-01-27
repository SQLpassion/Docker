# The customized image is based on the SQL Server 2019 from SQLpassion
FROM sqlpassion/sqlserver:2019-latest

# Switch to the root user
USER root

# Sets the pwd and chown to the service account of SQL Server
WORKDIR /tmp
RUN chown mssql /tmp

# Copy the scripts and the sample databases into the image
COPY sql /tmp/
COPY scripts /tmp/
COPY certs /tmp/

# Mark the scripts as executable
RUN chmod +x /tmp/*.sh

# Convert CRLF to LF in case Windows or VS Code changed it
RUN find . -type f \( -name "*.sql" -o -name "*.env" -o -name "*.sh" \) -exec sed -i 's/\r$//' {} \;

# Switch to user mssql or the container will fail
USER mssql

# Run the initial setup script
RUN /bin/bash /tmp/start-sqlserver.sh

# Label everything
LABEL org.opencontainers.image.vendor="SQLpassion"
LABEL org.opencontainers.image.title="SQLpassion"
LABEL org.opencontainers.image.url=https://www.sqlpassion.at
LABEL org.opencontainers.image.version=1.0
LABEL org.label-schema.description="SQL Server instance with some sample databases."
LABEL org.opencontainers.image.authors="Klaus Aschenbrenner <klaus.aschenbrenner@sqlpassion.at>"