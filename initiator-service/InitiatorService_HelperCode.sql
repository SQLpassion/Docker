select cast(message_body as xml), * from initiatorqueue

select * from sys.routes

select @@SERVERNAME


select * from ProcessedMessages


exec SendMessageToTargetService
'<HelloWorldRequest>
		Klaus Aschenbrenner
</HelloWorldRequest>'
GO

-- Sending a message from the InitiatorService to the TargetService
CREATE PROCEDURE SendMessageToTargetService
(
	@msg NVARCHAR(MAX)
)
AS
BEGIN TRY
	BEGIN TRANSACTION;
		DECLARE @ch UNIQUEIDENTIFIER
		
		BEGIN DIALOG CONVERSATION @ch
			FROM SERVICE InitiatorService
			TO SERVICE 'TargetService'
			ON CONTRACT TestContract
			WITH ENCRYPTION = OFF;

		SEND ON CONVERSATION @ch MESSAGE TYPE RequestMessage (@msg);
	COMMIT
END TRY
BEGIN CATCH
	ROLLBACK TRANSACTION
END CATCH
GO


-- Service program for the service "InitiatorService"
DECLARE @ch UNIQUEIDENTIFIER
DECLARE @messagetypename NVARCHAR(256)
DECLARE	@messagebody XML;

BEGIN TRY
	BEGIN TRANSACTION
		WAITFOR (
			RECEIVE TOP (1)
				@ch = conversation_handle,
				@messagetypename = message_type_name,
				@messagebody = CAST(message_body AS XML)
			FROM InitiatorQueue
		), TIMEOUT 60000

		IF (@@ROWCOUNT > 0)
		BEGIN
			IF (@messagetypename = 'ResponseMessage')
			BEGIN
				-- Store the received response) message in a table
				INSERT INTO ProcessedMessages (ID, MessageBody, ServiceName) VALUES (NEWID(), @messagebody, 'InitiatorService')
			END

			IF (@messagetypename = 'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
			BEGIN
				-- End the conversation on the initiator's side
				END CONVERSATION @ch;
			END
		END
	COMMIT
END TRY
BEGIN CATCH
	ROLLBACK TRANSACTION
END CATCH
GO




select transmission_status, * from sys.transmission_queue

select * from sys.conversation_endpoints

end conversation '0b27433e-f36b-1410-843e-00c781ecc772'

select * from sys.service_queues


select * from sys.service

select * from sys.databases


select * from sys.routes

drop route targetserviceroute


CREATE ROUTE TargetServiceRoute
	WITH SERVICE_NAME = 'TargetService',
	ADDRESS	= 'TCP://172.18.0.3:4741'
GO

CREATE ROUTE TargetServiceRoute
	WITH SERVICE_NAME = 'TargetService',
	ADDRESS	= 'TCP://target-service:4741'
GO

CREATE ROUTE TargetServiceRoute
	WITH SERVICE_NAME = 'TargetService',
	ADDRESS	= 'TCP://target-service.docker_localnet:4741'
GO


drop endpoint InitiatorServiceEndpoint

CREATE ENDPOINT InitiatorServiceEndpoint
STATE = STARTED
AS TCP 
(
	LISTENER_PORT = 4740
)
FOR SERVICE_BROKER 
(
	AUTHENTICATION = CERTIFICATE InitiatorServiceCertPrivate
)
GO

GRANT CONNECT ON ENDPOINT::InitiatorServiceEndpoint TO TargetServiceLogin
GO

GRANT SEND ON SERVICE::[InitiatorService] TO PUBLIC
GO



CREATE PROCEDURE ProcessResponseMessages
AS
	DECLARE @ch UNIQUEIDENTIFIER -- conversation handle
	DECLARE @messagetypename NVARCHAR(256)
	DECLARE	@messagebody XML;

	WHILE (1 = 1)
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION

			WAITFOR (
				RECEIVE TOP(1)
					@ch = conversation_handle,
					@messagetypename = message_type_name,
					@messagebody = CAST(message_body AS XML)
				FROM InitiatorQueue
			), TIMEOUT 60000

			IF (@@ROWCOUNT = 0)
			BEGIN
				ROLLBACK TRANSACTION
				BREAK
			END

			IF (@messagetypename = 'ResponseMessage')
			BEGIN
				-- Store the received response) message in a table
				INSERT INTO ProcessedMessages (ID, MessageBody, ServiceName) VALUES (NEWID(), @messagebody, 'InitiatorService')
			END

			IF (@messagetypename = 'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
			BEGIN
				-- End the conversation on the initiator's side
				END CONVERSATION @ch;
			END

			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION
		END CATCH
	END
GO

ALTER QUEUE InitiatorQueue
WITH ACTIVATION
(
	STATUS = ON,
	PROCEDURE_NAME = ProcessResponseMessages,
	MAX_QUEUE_READERS = 1,
	EXECUTE AS SELF
)
GO