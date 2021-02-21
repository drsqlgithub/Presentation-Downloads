--the table structure.  

USE [HowToImplementDataIntegrity]
go

--CREATE SCHEMA Demo
go

DROP TABLE Demo.[HighlyFormattedData]
go
CREATE TABLE Demo.[HighlyFormattedData](
	[HighlyFormattedData] [int] NOT NULL,
	[AlternateKeyValue] [char](10) NOT NULL,
	[FormattedValue1] [char](20) NULL,
	[FormattedValue2] [char](20) NULL,
	[FormattedValue3] [nvarchar](10) NULL,
	[FormattedValue4] [int] NULL,
	[FormattedValue5] [char](20) NULL,
	[FormattedValue6] [char](60) NULL,
	[FormattedValue7] [float] NULL,
	[FormattedValue8] [char](10) NULL,
	[FormattedValue9] [nchar](20) NULL,
	[FormattedValue10] [nchar](15) NULL,
	[FormattedValue11] [varchar](20) NULL,
	[FormattedValue12] [varchar](20) NULL,
	[FormattedValue13] [varchar](20) NULL,
	[FormattedValue14] [date] NULL,
	[FormattedValue15] [datetime] NULL,
	RowCreatedTime DATETIME2(3) NOT NULL,
	RowLastModifiedTime DATETIME2(3) NOT NULL,
	CONSTRAINT [PKHighlyFormattedData] PRIMARY KEY CLUSTERED 
	(
		[HighlyFormattedData] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY],
	CONSTRAINT [AKHighlighFormattedData] UNIQUE NONCLUSTERED 
	(
		[AlternateKeyValue] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO


ALTER TABLE Demo.[HighlyFormattedData]  WITH CHECK ADD  CONSTRAINT [CHKHighlyFormattedData_FormattedValue1] CHECK  (([FormattedValue1] like '[a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z]'))
GO

ALTER TABLE Demo.[HighlyFormattedData]  WITH CHECK ADD  CONSTRAINT [CHKHighlyFormattedData_FormattedValue10] CHECK  (([FormattedValue10] like '[0123][0123][0123][0123][0123][0123][0123][456][456][456][456][456][456][789][789]'))
GO

ALTER TABLE Demo.[HighlyFormattedData]  WITH CHECK ADD  CONSTRAINT [CHKHighlyFormattedData_FormattedValue11] CHECK  ((len([FormattedValue11])>(0)))
GO

ALTER TABLE Demo.[HighlyFormattedData]  WITH CHECK ADD  CONSTRAINT [CHKHighlyFormattedData_FormattedValue12] CHECK  ((len([FormattedValue12])>(0)))
GO

ALTER TABLE Demo.[HighlyFormattedData]  WITH CHECK ADD  CONSTRAINT [CHKHighlyFormattedData_FormattedValue13] CHECK  (([FormattedValue13] like '[a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z]'))
GO

ALTER TABLE Demo.[HighlyFormattedData]  WITH CHECK ADD  CONSTRAINT [CHKHighlyFormattedData_FormattedValue14] CHECK  (([FormattedValue14]>='20010101' AND [FormattedValue14]<='20111231'))
GO

ALTER TABLE Demo.[HighlyFormattedData]  WITH CHECK ADD  CONSTRAINT [CHKHighlyFormattedData_FormattedValue15] CHECK  (([FormattedValue15]>='20010101' AND [FormattedValue15]<='20111231'))
GO

ALTER TABLE Demo.[HighlyFormattedData]  WITH CHECK ADD  CONSTRAINT [CHKHighlyFormattedData_FormattedValue2] CHECK  (([FormattedValue2] like '[a-z][0-9][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z]'))
GO

ALTER TABLE Demo.[HighlyFormattedData]  WITH CHECK ADD  CONSTRAINT [CHKHighlyFormattedData_FormattedValue3] CHECK  (([FormattedValue3] like replicate('[a-z1]',len([FormattedValue3]))))
GO

ALTER TABLE Demo.[HighlyFormattedData]  WITH CHECK ADD  CONSTRAINT [CHKHighlyFormattedData_FormattedValue4] CHECK  (([FormattedValue4]>=(1) AND [FormattedValue4]<=(100)))
GO

ALTER TABLE Demo.[HighlyFormattedData]  WITH CHECK ADD  CONSTRAINT [CHKHighlyFormattedData_FormattedValue5] CHECK  (([FormattedValue5] like '[a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z]'))
GO

ALTER TABLE Demo.[HighlyFormattedData]  WITH CHECK ADD  CONSTRAINT [CHKHighlyFormattedData_FormattedValue6] CHECK  (([FormattedValue6] like replicate('[0123abc]',(60))))
GO

ALTER TABLE Demo.[HighlyFormattedData]  WITH CHECK ADD  CONSTRAINT [CHKHighlyFormattedData_FormattedValue7] CHECK  (([FormattedValue7]>=(0.0000000000000001) AND [FormattedValue7]<=(10000000000000.)))
GO

ALTER TABLE Demo.[HighlyFormattedData]  WITH CHECK ADD  CONSTRAINT [CHKHighlyFormattedData_FormattedValue8] CHECK  (([FormattedValue8] like '[a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z]'))
GO

ALTER TABLE Demo.[HighlyFormattedData]  WITH CHECK ADD  CONSTRAINT [CHKHighlyFormattedData_FormattedValue9] CHECK  (([FormattedValue9] like '[a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z][a-z]'))
GO


CREATE TRIGGER Demo.HighlyFormattedData$InsteadOfInsert
ON Demo.HighlyFormattedData
INSTEAD OF INSERT
AS
BEGIN
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
     @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --@rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;


   BEGIN TRY
          --[validation section] In this section, you should just look for issues and THROW errors

          --[modification section] In this section, the goal is no errors but do any data mods to other tables
		  --                       here. Rarely used for instead of triggers

          --<perform action>  In this section (generally the only one used in an instead of trigger), you
		                    --will usually cause the operation replaced by the trigger to occur
		  INSERT INTO Demo.HighlyFormattedData
           (HighlyFormattedData,AlternateKeyValue,FormattedValue1
           ,FormattedValue2,FormattedValue3,FormattedValue4,FormattedValue5,FormattedValue6
           ,FormattedValue7,FormattedValue8,FormattedValue9,FormattedValue10,FormattedValue11
           ,FormattedValue12,FormattedValue13,FormattedValue14,FormattedValue15,
		    RowLastModifiedTime, RowCreatedTime)
			SELECT HighlyFormattedData,AlternateKeyValue,FormattedValue1
					   ,FormattedValue2,FormattedValue3,FormattedValue4,FormattedValue5,FormattedValue6
					   ,FormattedValue7,FormattedValue8,FormattedValue9,FormattedValue10,FormattedValue11
					   ,FormattedValue12,FormattedValue13,FormattedValue14,FormattedValue15,
					   SYSDATETIME(), SYSDATETIME()
			FROM   INSERTED 
						
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

  --    --[Error logging section]
		--DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
		--        @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
		--        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
		--EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO

