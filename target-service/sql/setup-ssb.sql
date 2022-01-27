USE master
GO

-- Create a new database for the TargetService
CREATE DATABASE TargetService
GO

ALTER DATABASE TargetService SET TRUSTWORTHY ON
GO

USE TargetService
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

-- Create the TargetQueue
CREATE QUEUE TargetQueue WITH STATUS = ON
GO

-- Create the TargetService
CREATE SERVICE TargetService
ON QUEUE TargetQueue 
(
	TestContract
)
GO

-- Create a route to the InitiatorService
CREATE ROUTE InitiatorServiceRoute
	WITH SERVICE_NAME = 'InitiatorService',
	ADDRESS	= 'TCP://initiator-service:4740'
GO

--  Create a table to store the processed messages
CREATE TABLE ProcessedMessages
(
	ID UNIQUEIDENTIFIER NOT NULL,
	MessageBody XML NOT NULL,
	ServiceName NVARCHAR(MAX) NOT NULL
)
GO

-- These settings are needed, so that the activated stored procedure works...
-- Otherwise we get an error, and the queue is finally deactivated, because of the poison message handling.
SET ANSI_WARNINGS ON
GO

SET ANSI_PADDING ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- Create a stored procedure that processes the incoming request messages
CREATE PROCEDURE ProcessRequestMessages
AS
	DECLARE @ch UNIQUEIDENTIFIER
	DECLARE @messagetypename NVARCHAR(256)
	DECLARE	@messagebody XML
	DECLARE @responsemessage XML;

	WHILE (1 = 1)
	BEGIN
		BEGIN TRANSACTION

		WAITFOR (
			RECEIVE TOP(1)
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

			IF (@messagetypename = 'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
			BEGIN
				-- End the conversation
				END CONVERSATION @ch;
			END
		END

		COMMIT TRANSACTION
	END
GO

-- Configure the stored procedure as a service program on the queue
ALTER QUEUE TargetQueue
WITH ACTIVATION
(
	STATUS = ON,
	PROCEDURE_NAME = ProcessRequestMessages,
	MAX_QUEUE_READERS = 1,
	EXECUTE AS OWNER
)
GO

-- ***************
-- Security Setup 
-- ***************

USE master
GO

CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'password1!'
GO

CREATE CERTIFICATE TargetServiceCertPrivate FROM FILE = '/tmp/target-service-cert-public.cer'
WITH PRIVATE KEY
(
    FILE = '/tmp/target-service-cert-private.key', 
    DECRYPTION BY PASSWORD = 'passw0rd1!'
)
GO

-- Create a new Service Broker endpoint
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

-- Create a new login and user for the InitiatorService
CREATE LOGIN InitiatorServiceLogin WITH PASSWORD = 'password1!'
GO

CREATE USER InitiatorServiceUser FOR LOGIN InitiatorServiceLogin
GO

-- Import the public key certificate from the InitiatorService
CREATE CERTIFICATE InitiatorServiceCertPublic
	AUTHORIZATION InitiatorServiceUser
	FROM FILE = '/tmp/initiator-service-cert-public.cer'
GO

-- Grant the CONNECT permission to the InitiatorServiceLogin
GRANT CONNECT ON ENDPOINT::TargetServiceEndpoint TO InitiatorServiceLogin
GO

USE TargetService
GO

GRANT SEND ON SERVICE::[TargetService] TO PUBLIC
GO