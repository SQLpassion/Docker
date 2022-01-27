select cast(message_body as xml), * from targetqueue

select * from ProcessedMessages


RECEIVE TOP(1)
				* 
				FROM TargetQueue

-- Send a response message back to the service "InitiatorService"
DECLARE @ch UNIQUEIDENTIFIER
DECLARE @messagetypename NVARCHAR(256)
DECLARE	@messagebody XML
DECLARE @responsemessage XML;

BEGIN TRY
	BEGIN TRANSACTION
		WAITFOR (
			RECEIVE TOP (1)
				@ch = conversation_handle,
				@messagetypename = message_type_name,
				@messagebody = CAST(message_body AS XML)
			FROM TargetQueue
		), TIMEOUT 60000

		IF (@@ROWCOUNT > 0)
		BEGIN
			IF (@messagetypename = 'RequestMessage')
			BEGIN
				-- Store the received request message in a table
				INSERT INTO ProcessedMessages (ID, MessageBody, ServiceName) VALUES (NEWID(), @messagebody, 'TargetService')

				-- Construct the response message
				SET @responsemessage = '<HelloWorldResponse>' + @messagebody.value('/HelloWorldRequest[1]', 'NVARCHAR(MAX)') + '</HelloWorldResponse>';

				-- Send the response message back to the initiating service
				SEND ON CONVERSATION @ch MESSAGE TYPE ResponseMessage (@responsemessage);

				-- End the conversation on the target's side
				END CONVERSATION @ch;
			END
		END
	COMMIT
END TRY
BEGIN CATCH
	ROLLBACK TRANSACTION
END CATCH
GO


select @@SERVERNAME



select * from sys.service_contracts


select * from sys.transmission_queue

select * from sys.conversation_endpoints

select * from sys.service_queues

select * from sys.routes

select * from sys.endpoints


drop route InitiatorServiceRoute

CREATE ROUTE InitiatorServiceRoute
	WITH SERVICE_NAME = 'InitiatorService',
	ADDRESS	= 'TCP://initiator-service.docker_localnet:4740'
GO

CREATE ROUTE InitiatorServiceRoute
	WITH SERVICE_NAME = 'InitiatorService',
	ADDRESS	= 'TCP://initiator-service:4740'
GO


CREATE ROUTE InitiatorServiceRoute
	WITH SERVICE_NAME = 'InitiatorService',
	ADDRESS	= 'TCP://172.18.0.2:4740'
GO

drop endpoint TargetServiceEndpoint


CREATE ENDPOINT TargetServiceEndpoint
STATE = STARTED
AS TCP 
(
	LISTENER_PORT = 4741
)
FOR SERVICE_BROKER 
(
	AUTHENTICATION = CERTIFICATE TargetServiceCertPrivate
)
GO

GRANT CONNECT ON ENDPOINT::TargetServiceEndpoint TO InitiatorServiceLogin
GO


GRANT SEND ON SERVICE::[TargetService] TO PUBLIC
GO

exec ProcessRequestMessages
go


CREATE PROCEDURE ProcessRequestMessages
AS
	DECLARE @ch UNIQUEIDENTIFIER
	DECLARE @messagetypename NVARCHAR(256)
	DECLARE	@messagebody XML
	DECLARE @responsemessage XML;

	WHILE (1=1)
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION

			WAITFOR (
				RECEIVE TOP(1)
					@ch = conversation_handle,
					@messagetypename = message_type_name,
					@messagebody = CAST(message_body AS XML)
				FROM TargetQueue
			), TIMEOUT 60000

			IF (@@ROWCOUNT = 0)
			BEGIN
				ROLLBACK TRANSACTION
				BREAK
			END

			IF (@messagetypename = 'RequestMessage')
			BEGIN
				-- Store the received request message in a table
				INSERT INTO ProcessedMessages (ID, MessageBody, ServiceName) VALUES (NEWID(), @messagebody, 'TargetService')

				-- Construct the response message
				SET @responsemessage = '<HelloWorldResponse>' + @messagebody.value('/HelloWorldRequest[1]', 'NVARCHAR(MAX)') + '</HelloWorldResponse>';

				-- Send the response message back to the initiating service
				SEND ON CONVERSATION @ch MESSAGE TYPE ResponseMessage (@responsemessage);

				-- End the conversation on the target's side
				END CONVERSATION @ch;
			END

			IF (@messagetypename = 'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
			BEGIN
				-- End the conversation
				END CONVERSATION @ch;
			END

			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION
		END CATCH
	END
GO

ALTER QUEUE TargetQueue
WITH ACTIVATION
(
	STATUS = OFF
)

,
	PROCEDURE_NAME = ProcessRequestMessages,
	MAX_QUEUE_READERS = 1,
	EXECUTE AS SELF
)
GO

ALTER QUEUE TargetQueue
WITH 
status = ON


select is_receive_enabled, * from sys.service_queues

drop queue targetqueue
