-- These settings are needed, so that the activated stored procedure works...
-- Otherwise we get an error, and the queue is finally deactivated, because of the poison message handling.
SET ANSI_WARNINGS ON
GO

SET ANSI_PADDING ON
GO

SET QUOTED_IDENTIFIER ON
GO

USE master
GO

-- Create a new database for the InitiatorService
CREATE DATABASE InitiatorService
GO

ALTER DATABASE InitiatorService SET TRUSTWORTHY ON
GO

USE InitiatorService
GO

-- *********************
-- Service Broker Setup 
-- *********************

-- Create the message types that are used between the InitiatorService and the TargetService
CREATE MESSAGE TYPE RequestMessage VALIDATION = WELL_FORMED_XML
CREATE MESSAGE TYPE ResponseMessage VALIDATION = WELL_FORMED_XML
GO

-- Create the contract
CREATE CONTRACT TestContract
(
	RequestMessage SENT BY INITIATOR,
	ResponseMessage SENT BY TARGET
)
GO

-- Create the InitiatorQueue
CREATE QUEUE InitiatorQueue WITH STATUS = ON
GO

-- Create the InitiatorService
CREATE SERVICE InitiatorService
ON QUEUE InitiatorQueue 
(
	TestContract
)
GO

-- Create a route to the TargetService
CREATE ROUTE TargetServiceRoute
	WITH SERVICE_NAME = 'TargetService',
	ADDRESS	= 'TCP://target-service:4741'
GO

--  Create a table to store the processed messages
CREATE TABLE ProcessedMessages
(
	ID UNIQUEIDENTIFIER NOT NULL,
	MessageBody XML NOT NULL,
	ServiceName NVARCHAR(MAX) NOT NULL
)
GO

-- Create a stored procedure that processes the incoming response and EndDialog messages
CREATE PROCEDURE ProcessResponseMessages
AS
	DECLARE @ch UNIQUEIDENTIFIER -- conversation handle
	DECLARE @messagetypename NVARCHAR(256)
	DECLARE	@messagebody XML;

	WHILE (1 = 1)
	BEGIN
		BEGIN TRANSACTION

		WAITFOR (
			RECEIVE TOP(1)
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

		COMMIT TRANSACTION
	END
GO

-- -- Configure the stored procedure as a service program on the queue
ALTER QUEUE InitiatorQueue
WITH ACTIVATION
(
	STATUS = ON,
	PROCEDURE_NAME = ProcessResponseMessages,
	MAX_QUEUE_READERS = 1,
	EXECUTE AS OWNER
)
GO

-- Create a stored procedure that sends a message from the InitiatorService to the TargetService
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

-- ***************
-- Security Setup 
-- ***************

USE master
GO

CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'password1!'
GO

CREATE CERTIFICATE InitiatorServiceCertPrivate FROM FILE = '/tmp/initiator-service-cert-public.cer'
WITH PRIVATE KEY
(
    FILE = '/tmp/initiator-service-cert-private.key', 
    DECRYPTION BY PASSWORD = 'passw0rd1!'
)
GO

-- Create a new Service Broker endpoint
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

-- Create a new login and user for the TargetService
CREATE LOGIN TargetServiceLogin WITH PASSWORD = 'password1!'
GO

CREATE USER TargetServiceUser FOR LOGIN TargetServiceLogin
GO

-- Import the public key certificate from the TargetService
CREATE CERTIFICATE TargetServiceCertPublic
	AUTHORIZATION TargetServiceUser
	FROM FILE = '/tmp/target-service-cert-public.cer'
GO

-- Grant the CONNECT permission to the TargetService
GRANT CONNECT ON ENDPOINT::InitiatorServiceEndpoint TO TargetServiceLogin
GO

USE InitiatorService
GO

GRANT SEND ON SERVICE::[InitiatorService] TO PUBLIC
GO