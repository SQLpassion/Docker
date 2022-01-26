# Export the necessary environment variables
export $(xargs < /tmp/sapassword.env)
export $(xargs < /tmp/sqlcmd.env)
export PATH=$PATH:/opt/mssql-tools/bin

# Set the SQL Server configuration
cp /tmp/mssql.conf /var/opt/mssql/mssql.conf

# Start up SQL Server, wait for it, and then restore the sample databases
/opt/mssql/bin/sqlservr & sleep 20 & /tmp/configure.sh