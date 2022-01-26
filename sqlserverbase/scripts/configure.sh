# Loop until SQL Server is up and running
for i in {1..50};
do
    sqlcmd -S localhost -d master -Q "SELECT @@VERSION"
    if [ $? -ne 0 ];then
        sleep 2
    fi
done

# Restore the sample databases
sqlcmd -S localhost -d master -i /tmp/restore-databases.sql