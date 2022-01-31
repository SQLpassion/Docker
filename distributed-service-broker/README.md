# Docker

This repository contains a fully distributed Service Broker application deployed through Docker Compose.

## How to use it

Just run the following command from the command line - after fetching the latest version of the Docker repository:

```shell
docker-compose up -d
```

This commannd builds and runs the `initiator-service` and `target-service`, which are based on the `sqlpassion/sqlserver:2019-latest` Docker image.
After the successful completion of the command, you can verify with the following command, if you have 2 Docker containers up and running:

```shell
docker ps -a
```

The `initiator-service` is accessible through `localhost,1433`, and the `target-service` is acessible through `localhost,1434`.
When you have connected to both SQL Server instances (through SQL Server Management Studio or Azure Data Studio), you can send with the following T-SQL statement
a Service Broker message from the `initiator-service` to the `target-service`:

```shell
USE InitiatorService
GO

EXEC SendMessageToTargetService
'<HelloWorldRequest>
		Klaus Aschenbrenner
</HelloWorldRequest>'
GO
```

After the execution of the stored procedure, you should have a response message in the table `ProcessedMessages` on both SQL Server instances:

```shell
-- On the Initiator Service side (localhost,1433):
SELECT * FROM InitiatorService.dbo.ProcessedMessages
GO

-- On the Target Service side (localhost,1434):
SELECT * FROM TargetService.dbo.ProcessedMessages
GO
```
The whole messages, which are exchanged between both Service Broker services, are processed by the following activated stored procedures:

*) InitiatorService.dbo.ProcessResponseMessages
*) TargetService.dbo.ProcessRequestMessages