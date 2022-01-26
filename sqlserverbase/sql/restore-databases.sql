USE master
GO

-- Restore the AdventureWorks2014 database
RESTORE DATABASE AdventureWorks2014 FROM DISK = '/tmp/AdventureWorks2014.bak'
WITH
MOVE 'AdventureWorks2014_Data' TO '/var/opt/mssql/data/AdventureWorks2014.mdf',
MOVE 'AdventureWorks2014_Log'  TO '/var/opt/mssql/data/AdventureWorks2014.ldf'
GO