use master
Go

--drop db if you are recreating it, dropping all connections to existing database.
if exists (select * from sys.databases where name = 'ConferenceMessaging')
 exec ('
alter database  ConferenceMessaging
	set single_user with rollback immediate;

drop database ConferenceMessaging;')


CREATE DATABASE ConferenceMessaging 
GO
use ConferenceMessaging
go
select server_principals.name as Owner_name, databases.*
from   sys.databases
		 left outer join sys.server_principals
			on databases.owner_sid = server_principals.sid
where  databases.name = db_name(db_id())
GO

ALTER AUTHORIZATION ON Database::ConferenceMessaging to SA;
GO
CREATE SCHEMA Messages; --tables pertaining to the messages being sent
GO
CREATE SCHEMA Attendees; --tables pertaining to the attendees and how they can send messages
GO
select *
from   sys.schemas
		 join sys.database_principals
			on schemas.principal_id = database_principals.principal_id
where schemas.schema_id <> schemas.principal_id
GO

ALTER AUTHORIZATION ON SCHEMA::Messages To DBO;
GO
ALTER AUTHORIZATION ON SCHEMA::Attendees To DBO;
GO

CREATE SEQUENCE Messages.TopicIdGenerator
AS INT    
MINVALUE 10000 --starting value
NO MAXVALUE --technically will max out at max int
START WITH 10000 --value where the sequence will start, differs from min based on 
             --cycle property
INCREMENT BY 1 --number that is added the previous value
NO CYCLE --if setting is cycle, when it reaches max value it starts over
CACHE 100; --Use adjust number of values that SQL Server caches. Cached values would
          --be lost if the server is restarted, but keeping them in RAM makes access faster;
GO

select next value for MEssages.TopicIdGenerator

alter sequence Messages.TopicIdGenerator restart
GO

CREATE TABLE Attendees.AttendeeType ( 
	AttendeeType         varchar(20)  NOT NULL ,
	Description          varchar(60)  NOT NULL 
);
--As this is a non-editable table, we load the data here to
--start with
INSERT INTO Attendees.AttendeeType
VALUES ('Regular', 'Typical conference attendee'),
	   ('Speaker', 'Person scheduled to speak'),
	   ('Administrator','Manages System');
GO

CREATE TABLE Attendees.MessagingUser ( 
	MessagingUserId      int IDENTITY ( 1,1 ) ,
	UserHandle           varchar(20)  NOT NULL ,
	AccessKeyValue       char(10)  NOT NULL ,
	AttendeeNumber       char(8)  NOT NULL ,
	FirstName            varchar(50)  NULL ,
	LastName             varchar(50)  NULL ,
	AttendeeType         varchar(20)  NOT NULL ,
	DisabledFlag         bit  NOT NULL ,
	RowCreateTime        datetime2(0)  NOT NULL ,
	RowLastUpdateTime    datetime2(0)  NOT NULL 
);
CREATE TABLE Attendees.UserConnection
( 
	UserConnectionId     int NOT NULL IDENTITY ( 1,1 ) ,
	ConnectedToMessagingUserId int  NOT NULL ,
	MessagingUserId      int  NOT NULL ,
	RowCreateTime        datetime2(0)  NOT NULL ,
	RowLastUpdateTime    datetime2(0)  NOT NULL 
);

/*
select dateadd(hour,datepart(hour,sysdatetime()),
	                               cast(cast(sysdatetime() as date)as datetime2(0)) )
*/

CREATE TABLE Messages.Message ( 
	MessageId            int NOT NULL IDENTITY ( 1,1 ) ,
	RoundedMessageTime  as (dateadd(hour,datepart(hour,MessageTime),
	                               cast(cast(MessageTime as date)as datetime2(0)) ))
                                       PERSISTED,
	SentToMessagingUserId int  NULL ,
	MessagingUserId      int  NOT NULL ,
	Text                 nvarchar(200)  NOT NULL ,
	MessageTime          datetime2(0)  NOT NULL ,
	RowCreateTime        datetime2(0)  NOT NULL ,
	RowLastUpdateTime    datetime2(0)  NOT NULL 
);
CREATE TABLE Messages.MessageTopic ( 
	MessageTopicId       int NOT NULL IDENTITY ( 1,1 ) ,
	MessageId            int  NOT NULL ,
	UserDefinedTopicName nvarchar(30)  NULL ,
	TopicId              int  NOT NULL ,
	RowCreateTime        datetime2(0)  NOT NULL ,
	RowLastUpdateTime    datetime2(0)  NOT NULL 
);

CREATE TABLE Messages.Topic ( 
        TopicId int NOT NULL CONSTRAINT DFLTMessage_Topic_TopicId 
                                DEFAULT(NEXT VALUE FOR  Messages.TopicIdGenerator),
	Name                 nvarchar(30)  NOT NULL ,
	Description          varchar(60)  NOT NULL ,
	RowCreateTime        datetime2(0)  NOT NULL ,
	RowLastUpdateTime    datetime2(0)  NOT NULL 
);
go
--gives an error...
--INSERT INTO Messages.Topic(TopicId, Name, Description)
--VALUES (0,'User Defined','User Enters Their Own User Defined Topic');

INSERT INTO Messages.Topic(TopicId, Name, Description, RowCreateTime, RowLastUpdateTime)
VALUES (0,'User Defined','User Enters Their Own User Defined Topic',sysdatetime(), sysdatetime());
GO

ALTER TABLE Attendees.AttendeeType
     ADD CONSTRAINT PK_Attendees_AttendeeType PRIMARY KEY CLUSTERED (AttendeeType);

ALTER TABLE Attendees.MessagingUser
     ADD CONSTRAINT PK_Attendees_MessagingUser PRIMARY KEY CLUSTERED (MessagingUserId);

ALTER TABLE Attendees.UserConnection
     ADD CONSTRAINT PK_Attendees_UserConnection PRIMARY KEY CLUSTERED (UserConnectionId);
     
ALTER TABLE Messages.Message
     ADD CONSTRAINT PK_Messages_Message PRIMARY KEY CLUSTERED (MessageId);

ALTER TABLE Messages.MessageTopic
     ADD CONSTRAINT PK_Messages_MessageTopic PRIMARY KEY CLUSTERED (MessageTopicId);

ALTER TABLE Messages.Topic
     ADD CONSTRAINT PK_Messages_Topic PRIMARY KEY CLUSTERED (TopicId);
GO

ALTER TABLE Messages.Message
     ADD CONSTRAINT AK_Messages_Message_TimeUserAndText UNIQUE
      (RoundedMessageTime, MessagingUserId, Text);

ALTER TABLE Messages.Topic
     ADD CONSTRAINT AK_Messages_Topic_Name UNIQUE (Name);

ALTER TABLE Messages.MessageTopic
     ADD CONSTRAINT AK_Messages_MessageTopic_TopicAndMessage UNIQUE
      (MessageId, TopicId, UserDefinedTopicName);

ALTER TABLE Attendees.MessagingUser
     ADD CONSTRAINT AK_Attendees_MessagingUser_UserHandle UNIQUE (UserHandle);

ALTER TABLE Attendees.MessagingUser
     ADD CONSTRAINT AK_Attendees_MessagingUser_AttendeeNumber UNIQUE
     (AttendeeNumber);
     
ALTER TABLE Attendees.UserConnection
     ADD CONSTRAINT AK_Attendees_UserConnection_Users UNIQUE
     (MessagingUserId, ConnectedToMessagingUserId);
GO


ALTER TABLE Attendees.MessagingUser
   ADD CONSTRAINT DFAttendees_MessagingUser_DisabledFlag
   DEFAULT (0) FOR DisabledFlag;

GO
/*
SELECT 'ALTER TABLE ' + object_schema_name(object_id) + '.' +  object_name(object_id) + CHAR(13) + CHAR(10) +
       '    ADD CONSTRAINT DFLT' + object_schema_name(object_id) + '_' +  object_name(object_id) + '_' +
       name + CHAR(13) + CHAR(10) +
       '    DEFAULT (SYSDATETIME()) FOR ' + name + ';'
FROM   sys.columns
WHERE  name in ('RowCreateTime', 'RowLastUpdateTime')
  and  object_schema_name(object_id) in ('Messages','Attendees')
ORDER BY object_schema_name(object_id), object_name(object_id), name
*/

--may be overridden by trigger, but good practice to have default
ALTER TABLE Attendees.MessagingUser
    ADD CONSTRAINT DFLTAttendees_MessagingUser_RowCreateTime
    DEFAULT (SYSDATETIME()) FOR RowCreateTime;

ALTER TABLE Attendees.MessagingUser
    ADD CONSTRAINT DFLTAttendees_MessagingUser_RowLastUpdateTime
    DEFAULT (SYSDATETIME()) FOR RowLastUpdateTime;

ALTER TABLE Attendees.UserConnection
    ADD CONSTRAINT DFLTAttendees_UserConnection_RowCreateTime
    DEFAULT (SYSDATETIME()) FOR RowCreateTime;

ALTER TABLE Attendees.UserConnection
    ADD CONSTRAINT DFLTAttendees_UserConnection_RowLastUpdateTime
    DEFAULT (SYSDATETIME()) FOR RowLastUpdateTime;

ALTER TABLE Messages.Message
    ADD CONSTRAINT DFLTMessages_Message_RowCreateTime
    DEFAULT (SYSDATETIME()) FOR RowCreateTime;

ALTER TABLE Messages.Message
    ADD CONSTRAINT DFLTMessages_Message_RowLastUpdateTime
    DEFAULT (SYSDATETIME()) FOR RowLastUpdateTime;

ALTER TABLE Messages.MessageTopic
    ADD CONSTRAINT DFLTMessages_MessageTopic_RowCreateTime
    DEFAULT (SYSDATETIME()) FOR RowCreateTime;

ALTER TABLE Messages.MessageTopic
    ADD CONSTRAINT DFLTMessages_MessageTopic_RowLastUpdateTime
    DEFAULT (SYSDATETIME()) FOR RowLastUpdateTime;

ALTER TABLE Messages.Topic
    ADD CONSTRAINT DFLTMessages_Topic_RowCreateTime
    DEFAULT (SYSDATETIME()) FOR RowCreateTime;

ALTER TABLE Messages.Topic
    ADD CONSTRAINT DFLTMessages_Topic_RowLastUpdateTime
    DEFAULT (SYSDATETIME()) FOR RowLastUpdateTime;

GO

ALTER TABLE Attendees.MessagingUser
       ADD CONSTRAINT FK__Attendees_MessagingUser$IsSent$Messages_Message
            FOREIGN KEY (AttendeeType) REFERENCES Attendees.AttendeeType(AttendeeType)
	    ON UPDATE CASCADE
            ON DELETE NO ACTION;

GO


ALTER TABLE Attendees.UserConnection
	ADD CONSTRAINT 
          FK__Attendees_MessagingUser$ConnectsToUserVia$Attendees_UserConnection 
        FOREIGN KEY (MessagingUserId) REFERENCES Attendees.MessagingUser(MessagingUserId)
	ON UPDATE NO ACTION
	ON DELETE NO ACTION;

ALTER TABLE Attendees.UserConnection
	ADD CONSTRAINT 
          FK__Attendees_MessagingUser$IsConnectedToUserVia$Attendees_UserConnection 
        FOREIGN KEY  (ConnectedToMessagingUserId) 
                              REFERENCES Attendees.MessagingUser(MessagingUserId)
	ON UPDATE NO ACTION
	ON DELETE NO ACTION;
Go


ALTER TABLE Messages.Message
	ADD CONSTRAINT FK__Messages_MessagingUser$Sends$Messages_Message FOREIGN KEY 
	    (MessagingUserId) REFERENCES Attendees.MessagingUser(MessagingUserId)
	ON UPDATE NO ACTION
	ON DELETE NO ACTION;

ALTER TABLE Messages.Message
	ADD CONSTRAINT FK__Messages_MessagingUser$IsSent$Messages_Message FOREIGN KEY 
	    (SentToMessagingUserId) REFERENCES Attendees.MessagingUser(MessagingUserId)
	ON UPDATE NO ACTION
	ON DELETE NO ACTION;
GO


ALTER TABLE Messages.MessageTopic
	ADD CONSTRAINT 
           FK__Messages_Topic$CategorizesMessagesVia$Messages_MessageTopic FOREIGN KEY 
	     (TopicId) REFERENCES Messages.Topic(TopicId)
	ON UPDATE NO ACTION
	ON DELETE NO ACTION;
GO


ALTER TABLE Messages.MessageTopic
	ADD CONSTRAINT FK__Message$iscCategorizedVia$MessageTopic FOREIGN KEY 
	    (MessageId) REFERENCES Messages.Message(MessageId)
	ON UPDATE NO ACTION
	ON DELETE NO ACTION;
GO

ALTER TABLE Messages.Topic
   ADD CONSTRAINT CHK__Messages_Topic_Name_NotEmpty
       CHECK (LEN(RTRIM(Name)) > 0);

ALTER TABLE Messages.MessageTopic
   ADD CONSTRAINT CHK__Messages_MessageTopic_UserDefinedTopicName_NotEmpty
       CHECK (LEN(RTRIM(UserDefinedTopicName)) > 0);
GO

ALTER TABLE Attendees.MessagingUser 
  ADD CONSTRAINT CHK__Attendees_MessagingUser_UserHandle_LenthAndStart
     CHECK (LEN(Rtrim(UserHandle)) >= 5 
             AND LTRIM(UserHandle) LIKE '[a-z]' +
                            REPLICATE('[a-z1-9]',LEN(RTRIM(UserHandle)) -1));
GO


ALTER TABLE Messages.MessageTopic
  ADD CONSTRAINT CHK__Messages_MessageTopic_UserDefinedTopicName_NullUnlessUserDefined
   CHECK ((UserDefinedTopicName is NULL and TopicId <> 0)
              or (TopicId = 0 and UserDefinedTopicName is NOT NULL));
GO

CREATE TRIGGER MessageTopic$InsteadOfInsertTrigger
ON Messages.MessageTopic
INSTEAD OF INSERT AS
BEGIN

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
          INSERT INTO Messages.MessageTopic (MessageId, UserDefinedTopicName,
                                            TopicId,RowCreateTime,RowLastUpdateTime)
          SELECT MessageId, UserDefinedTopicName, TopicId, SYSDATETIME(), SYSDATETIME()
          FROM   inserted ;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END
GO


CREATE TRIGGER Messages.MessageTopic$InsteadOfUpdateTrigger
ON Messages.MessageTopic
INSTEAD OF UPDATE AS
BEGIN

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
         UPDATE MessageTopic 
          SET   MessageId = Inserted.MessageId,
                UserDefinedTopicName = Inserted.UserDefinedTopicName,
                TopicId = Inserted.TopicId,
                RowCreateTime = MessageTopic.RowCreateTime, --no changes allowed
                RowLastUpdateTime = SYSDATETIME()
          FROM  inserted 
                   JOIN Messages.MessageTopic 
                        on inserted.MessageTopicId = MessageTopic.MessageTopicId;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END
GO


CREATE TRIGGER Messages.Topic$InsteadOfInsertTrigger
ON Messages.Topic
INSTEAD OF INSERT AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
          INSERT INTO Messages.Topic (TopicId, Name, Description,
										RowCreateTime,RowLastUpdateTime)
          SELECT TopicId, Name, Description,SYSDATETIME(), SYSDATETIME()
          FROM   inserted ;
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

			  THROW;
     END CATCH
END
GO
CREATE TRIGGER Topic$InsteadOfUpdateTrigger
ON Messages.Topic
INSTEAD OF UPDATE AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
		  UPDATE Topic 
		  SET Name = Inserted.Name,
			  Description = Inserted.Description,
		      RowCreateTime = Topic.RowCreateTime, --no changes allowed
		      RowLastUpdateTime = SYSDATETIME()
		  FROM   inserted 
		            join Messages.Topic 
				on inserted.TopicId = Topic.TopicId;
   END TRY
   BEGIN CATCH
        IF @@trancount > 0
            ROLLBACK TRANSACTION;
			 
		THROW;

     END CATCH
END
GO

CREATE TRIGGER Message$InsteadOfInsertTrigger
ON Messages.Message
INSTEAD OF INSERT AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
          INSERT INTO Messages.Message (SentToMessagingUserId, 
		                                MessagingUserId,Text, MessageTime, 
										RowCreateTime,RowLastUpdateTime)
          SELECT  SentToMessagingUserId, 
		          MessagingUserId,Text, MessageTime,SYSDATETIME(), SYSDATETIME()
          FROM   inserted ;
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

			  THROW;

     END CATCH
END
GO
CREATE TRIGGER Message$InsteadOfUpdateTrigger
ON Messages.Message
INSTEAD OF UPDATE AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
		  UPDATE Message 
		  SET SentToMessagingUserId  = Inserted.SentToMessagingUserId,
			  MessagingUserId = Inserted.MessagingUserId,
			  Text = Inserted.Text,
			  MessageTime = Inserted.MessageTime, 
		      RowCreateTime = Message.RowCreateTime, --no changes allowed
		      RowLastUpdateTime = SYSDATETIME()
		  FROM   inserted 
		            join Messages.Message 
				on inserted.MessageId = Message.MessageId
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

			  THROW;

     END CATCH
END
GO


CREATE TRIGGER MessagingUser$InsteadOfInsertTrigger
ON Attendees.MessagingUser
INSTEAD OF INSERT AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
          INSERT INTO Attendees.MessagingUser (UserHandle, AccessKeyValue, AttendeeNumber, FirstName, LastName,
		                                AttendeeType, DisabledFlag,
										RowCreateTime,RowLastUpdateTime)
          SELECT UserHandle, AccessKeyValue, AttendeeNumber, FirstName, LastName,
		                                AttendeeType, DisabledFlag,SYSDATETIME(), SYSDATETIME()
          FROM   inserted ;
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

			  THROW;

     END CATCH
END
GO


CREATE TRIGGER MessageTopic$UpdateRowControlsTrigger
ON Messages.MessageTopic
AFTER UPDATE AS
BEGIN
   --Since this is cascade, we will have to use an after trigger for the UPDATE trigger, 
   --since when the cascade occurs in the base table, the automatic operation won’t 
   --use the trigger, but only the base table operations. 

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          UPDATE MessageTopic 
          SET    RowCreateTime = SYSDATETIME(),
                 RowLastUpdateTime = SYSDATETIME()
          FROM   inserted 
                    JOIN Messages.MessageTopic 
                        on inserted.MessageTopicId = MessageTopic.MessageTopicId;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION

      THROW --will halt the batch or be caught by the caller's catch block

  END CATCH
END
GO

CREATE TRIGGER UserConnection$InsteadOfInsertTrigger
ON Attendees.UserConnection
INSTEAD OF INSERT AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
          INSERT INTO Attendees.UserConnection (ConnectedToMessagingUserId, MessagingUserId, 
										RowCreateTime,RowLastUpdateTime)
          SELECT ConnectedToMessagingUserId, MessagingUserId, SYSDATETIME(), SYSDATETIME()
          FROM   inserted ;
   END TRY
   BEGIN CATCH
        IF @@trancount > 0
            ROLLBACK TRANSACTION;

		THROW;
   END CATCH
END
GO

CREATE TRIGGER UserConnection$InsteadOfUpdateTrigger
ON Attendees.UserConnection
INSTEAD OF UPDATE AS
BEGIN

    DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
		  UPDATE UserConnection 
		  SET ConnectedToMessagingUserId = Inserted.ConnectedToMessagingUserId,
			  MessagingUserId = Inserted.MessagingUserId,
		      RowCreateTime = UserConnection.RowCreateTime, --no changes allowed
		      RowLastUpdateTime = SYSDATETIME()
		  FROM   inserted 
		            join Attendees.UserConnection 
				on inserted.UserConnectionId = UserConnection.UserConnectionId
   END TRY
   BEGIN CATCH
        IF @@trancount > 0
            ROLLBACK TRANSACTION;

		THROW;
   END CATCH
END
GO
 
go

--Messages schema 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Messaging objects',
   @level0type = 'Schema', @level0name = 'Messages';

--Messages.Topic table
EXEC sp_addextendedproperty @name = 'Description',
   @value = ' Pre-defined topics for messages',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic';

--Messages.Topic.TopicId 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing a Topic',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic',
   @level2type = 'Column', @level2name = 'TopicId';

--Messages.Topic.Name
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'The name of the topic',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic',
   @level2type = 'Column', @level2name = 'Name';

--Messages.Topic.Description
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Description of the purpose and utilization of the topics',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic',
   @level2type = 'Column', @level2name = 'Description';

--Messages.Topic.RowCreateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was created',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic',
   @level2type = 'Column', @level2name = 'RowCreateTime';

--Messages.Topic.RowLastUpdateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was last updated',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic',
   @level2type = 'Column', @level2name = 'RowLastUpdateTime';

EXEC sp_addextendedproperty @name = 'Description',
   @value = 'User Id of the user that is being sent a message',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name = 'SentToMessagingUserId';
   
--Messages.Message.MessagingUserId
EXEC sp_addextendedproperty @name = 'Description',
   @value ='User Id of the user that sent the message',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name =  'MessagingUserId';

--Messages.Message.Text 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Text of the message being sent',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name = 'Text';

--Messages.Message.MessageTime 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'The time the message is sent, at a grain of one second',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name = 'MessageTime';
 
 --Messages.Message.RowCreateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was created',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name = 'RowCreateTime';

--Messages.Message.RowLastUpdateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was last updated',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name = 'RowLastUpdateTime';
   

--Messages.Message table
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Relates a message to a topic',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic';

--Messages.Message.MessageTopicId 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing a MessageTopic',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'MessageTopicId';
   
   --Messages.Message.MessageId 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing the message that is being associated with a topic',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'MessageId';

--Messages.MessageUserDefinedTopicName 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Allows the user to choose the “UserDefined” topic style and set their own topic ',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'UserDefinedTopicName';

   --Messages.Message.TopicId
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing the topic that is being associated with a message',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'TopicId';

 --Messages.MessageTopic.RowCreateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was created',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'RowCreateTime';

--Messages.MessageTopic.RowLastUpdateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was last updated',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'RowLastUpdateTime';
GO

--Attendees schema 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Attendee objects',
   @level0type = 'Schema', @level0name = 'Attendees';

--Attendees.AttendeeType table
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Domain of the different types of attendees that are supported',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'AttendeeType';

--Attendees.AttendeeType.AttendeeType
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Code representing a type of Attendee',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'AttendeeType',
   @level2type = 'Column', @level2name = 'AttendeeType';

--Attendees.AttendeeType.AttendeeType
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Brief description explaining the Attendee Type',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'AttendeeType',
   @level2type = 'Column', @level2name = 'Description';


--Attendees.MessagingUser table
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Represent a user of the messaging system, preloaded from another system with attendee information',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser';

--Attendees.MessagingUser.MessagingUserId
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing a messaginguser',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'MessagingUserId';

--Attendees.MessagingUser.UserHandle
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'The name the user wants to be known as. Initially pre-loaded with a value based on the persons first and last name, plus a integer value, changeable by the user',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'UserHandle';

--Attendees.MessagingUser.AccessKeyValue
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'A password-like value given to the user on their badge to gain access',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'AccessKeyValue';

--Attendees.MessagingUser.AttendeeNumber
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'The number that the attendee is given to identify themselves, printed on front of badge',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'AttendeeNumber';

--Attendees.MessagingUser.FirstName
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Name of the user printed on badge for people to see',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'FirstName';

--Attendees.MessagingUser.LastName
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Name of the user printed on badge for people to see',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'LastName';

--Attendees.MessagingUser.AttendeeType
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Used to give the user special priviledges, such as access to speaker materials, vendor areas, etc.',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'AttendeeType';

--Attendees.MessagingUser.DisabledFlag
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Indicates whether or not the user'' account has been disabled',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'DisabledFlag';

--Attendees.MessagingUser.RowCreateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was created',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'RowCreateTime';

--Attendees.MessagingUser.RowLastUpdateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was last updated',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'RowLastUpdateTime';
GO

--Attendees.UserConnection table
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Represents the connection of one user to another in order to filter results to a given set of users.',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection';

--Attendees.MessagingUser.UserConnectionId
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing a messaginguser',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection',
   @level2type = 'Column', @level2name = 'UserConnectionId';

--Attendees.MessagingUser.UserConnectionId
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'MessagingUserId of user that is going to connect themselves to another users ',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection',
   @level2type = 'Column', @level2name = 'MessagingUserId';

--Attendees.MessagingUser.UserConnectionId
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'MessagingUserId of user that is being connected to',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection',
   @level2type = 'Column', @level2name = 'ConnectedToMessagingUserId';

--Attendees.MessagingUser.RowCreateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was created',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection',
   @level2type = 'Column', @level2name = 'RowCreateTime';

--Attendees.MessagingUser.RowLastUpdateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was last updated',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection',
   @level2type = 'Column', @level2name = 'RowLastUpdateTime';
GO

--schemas
select schemas.name, database_principals.name as ownerName,
		schemaProperties.description
from   sys.schemas
		 join sys.database_principals
			on schemas.principal_id = database_principals.principal_id
		 LEFT OUTER JOIN (select *,major_id as schema_id, value as Description
			from   sys.extended_properties
			where  class_desc = 'SCHEMA'
				and name = 'Description')	 as schemaProperties
				on schemas.schema_id = schemaProperties.schema_id
where schemas.schema_id <> schemas.principal_id
GO

--tables
select schemas.name as schemaName, tables.name as tableName, 
		tableProperties.description, 
		REPLACE(LOWER(type_desc), '_', ' ') AS table_type,
		CASE WHEN EXISTS ( SELECT *
				FROM   sys.key_constraints

				WHERE  key_constraints.type = 'PK'
					AND key_constraints.parent_object_id = tables.object_id) THEN 1
			ELSE 0
		END AS has_primary_key,
		CASE WHEN EXISTS ( SELECT *
							FROM   sys.key_constraints
							WHERE  key_constraints.type = 'UQ'
							  AND key_constraints.parent_object_id = tables.object_id) THEN 1
		ELSE 0
		END AS has_unique_key,
			uses_ansi_nulls,
			objectproperty(tables.object_id,'IsQuotedIdentOn') as quoted_identifiers
			--,*
from   sys.tables
            JOIN sys.schemas
                ON schemas.schema_id = tables.schema_id
			LEFT OUTER JOIN (select major_id as object_id, minor_id as column_id, value as Description
							from   sys.extended_properties
							where  class_desc = 'OBJECT_OR_COLUMN'
								and  minor_id = 0
								and name = 'Description')	 as tableProperties
				on tables.object_id = tableProperties.object_id
where  type_desc = 'User_table'


--column metadata
--column metadata
SELECT  *
FROM    ( 

   SELECT    REPLACE(LOWER(objects.type_desc), '_', ' ') AS table_type, schemas.name AS schema_name, objects.name AS table_name,
                    columns.name AS column_name, CASE WHEN columns.is_identity = 1 THEN 'IDENTITY NOT NULL'
                                                      WHEN columns.is_nullable = 1 THEN 'NULL'
                                                      ELSE 'NOT NULL'
                                                 END AS nullability,
                   --types that have a ascii character or binary length
                    CASE WHEN columns.is_computed = 1 THEN 'Computed'
                         WHEN types.name IN ( 'varchar', 'char', 'varbinary' ) THEN types.name + CASE WHEN columns.max_length = -1 THEN '(max)'
                                                                                                      ELSE '(' + CAST(columns.max_length AS VARCHAR(4)) + ')'
                                                                                                 END
                
                         --types that have an unicode character type that requires length to be halved
                         WHEN types.name IN ( 'nvarchar', 'nchar' ) THEN types.name + CASE WHEN columns.max_length = -1 THEN '(max)'
                                                                                           ELSE '(' + CAST(columns.max_length / 2 AS VARCHAR(4)) + ')'
                                                                                      END

                          --types with a datetime precision
                         WHEN types.name IN ( 'time', 'datetime2', 'datetimeoffset' ) THEN types.name + '(' + CAST(columns.scale AS VARCHAR(4)) + ')'

                         --types with a precision/scale
                         WHEN types.name IN ( 'numeric', 'decimal' )
                         THEN types.name + '(' + CAST(columns.precision AS VARCHAR(4)) + ',' + CAST(columns.scale AS VARCHAR(4)) + ')'

                        --timestamp should be reported as rowversion
                         WHEN types.name = 'timestamp' THEN 'rowversion'
                         --and the rest. Note, float is declared with a bit length, but is
                         --represented as either float or real in types 
                         ELSE types.name
                    END AS declared_datatype,

                   --types that have a ascii character or binary length
                    CASE WHEN types.is_assembly_type = 1 THEN 'CLR TYPE'
						 WHEN baseType.name IN ( 'varchar', 'char', 'varbinary' ) THEN baseType.name + CASE WHEN columns.max_length = -1 THEN '(max)'
                                                   ELSE '(' + CAST(columns.max_length AS VARCHAR(4)) + ')'
                                              END
                
                         --types that have an unicode character type that requires length to be halved
                         WHEN baseType.name IN ( 'nvarchar', 'nchar' ) THEN baseType.name + CASE WHEN columns.max_length = -1 THEN '(max)'
                                                                                                 ELSE '(' + CAST(columns.max_length / 2 AS VARCHAR(4)) + ')'
                                                                                            END

                         --types with a datetime precision
                         WHEN baseType.name IN ( 'time', 'datetime2', 'datetimeoffset' ) THEN baseType.name + '(' + CAST(columns.scale AS VARCHAR(4)) + ')'

                         --types with a precision/scale
                         WHEN baseType.name IN ( 'numeric', 'decimal' )
                         THEN baseType.name + '(' + CAST(columns.precision AS VARCHAR(4)) + ',' + CAST(columns.scale AS VARCHAR(4)) + ')'

                         --timestamp should be reported as rowversion
                         WHEN baseType.name = 'timestamp' THEN 'rowversion'
                         --and the rest. Note, float is declared with a bit length, but is
                         --represented as either float or real in types 
                         ELSE baseType.name
                    END AS base_datatype, CASE WHEN EXISTS ( SELECT *
                                                             FROM   sys.key_constraints
                                                                    JOIN sys.indexes
                                                                        ON key_constraints.parent_object_id = indexes.object_id
                                                                           AND key_constraints.unique_index_id = indexes.index_id
                                                                    JOIN sys.index_columns
                                                                        ON index_columns.object_id = indexes.object_id
                                                                           AND index_columns.index_id = indexes.index_id
                                                             WHERE  key_constraints.type = 'PK'
                                                                    AND columns.column_id = index_columns.column_id
                                                                    AND columns.OBJECT_ID = index_columns.OBJECT_ID ) THEN 1
                                               ELSE 0
                                          END AS primary_key_column, columns.column_id, default_constraints.definition AS default_value,
                    check_constraints.definition AS column_check_constraint,
                    CASE WHEN EXISTS ( SELECT   *
                                       FROM     sys.check_constraints AS cc
                                       WHERE    cc.parent_object_id = columns.OBJECT_ID
                                                AND cc.definition LIKE '%~[' + columns.name + '~]%' ESCAPE '~'
                                                AND cc.parent_column_id = 0 ) THEN 1
                         ELSE 0
                    END AS table_check_constraint_reference,
					columnProperties.Description
          FROM      sys.columns
                    JOIN sys.types
                        ON columns.user_type_id = types.user_type_id

                    left outer JOIN sys.types AS baseType
                        ON columns.system_type_id = baseType.system_type_id
                           AND baseType.user_type_id = baseType.system_type_id
                    JOIN sys.objects
                            JOIN sys.schemas
                                   ON schemas.schema_id = objects.schema_id
                        ON objects.object_id = columns.OBJECT_ID
                    LEFT OUTER JOIN sys.default_constraints
                        ON default_constraints.parent_object_id = columns.object_id
                              AND default_constraints.parent_column_id = columns.column_id
                    LEFT OUTER JOIN sys.check_constraints
                        ON check_constraints.parent_object_id = columns.object_id
                             AND check_constraints.parent_column_id = columns.column_id 
					LEFT OUTER JOIN (select major_id as object_id, minor_id as column_id, value as Description
									from   sys.extended_properties
									where  class_desc = 'OBJECT_OR_COLUMN'
									  and  minor_id > 0
									  and name = 'Description')	 as columnProperties
						on columns.object_id = columnProperties.object_id
						   and columns.column_id = columnProperties.column_id
							) AS rows
WHERE   table_type = 'user table'
              AND schema_name LIKE '%'
              AND table_name LIKE '%'
              AND column_name LIKE '%'
              AND nullability LIKE '%'
              AND base_datatype LIKE '%'
              AND declared_datatype LIKE '%'
ORDER BY table_type, schema_name, table_name, column_id
GO

GO

SELECT OBJECT_SCHEMA_NAME(parent_id) + '.' + OBJECT_NAME(parent_id) as TABLE_NAME, 
	   name as TRIGGER_NAME, 
	   case when is_instead_of_trigger = 1 then 'INSTEAD OF' else 'AFTER' End 
			as TRIGGER_FIRE_TYPE
FROM   sys.triggers
WHERE  type_desc = 'SQL_TRIGGER' --not a clr trigger
  and  parent_class = 1 --DML Triggers
ORDER BY TABLE_NAME, TRIGGER_NAME
GO

