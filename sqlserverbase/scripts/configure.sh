# Loop until SQL Server is up and running
for i in {1..50};
do
    sqlcmd -S localhost -d master -Q "SELECT @@VERSION"
    if [ $? -ne 0 ];then
        sleep 2
    fi
done

# Download the AdventureWork2014 backup file from GitHub
wget https://github.com/SQLpassion/Docker/raw/71ac56d9b5bbf517ca2deabd926853920db673d4/sqlserverbase/sample-databases/AdventureWorks2014.bak

# Restore the sample databases
sqlcmd -S localhost -d master -i /tmp/restore-databases.sql