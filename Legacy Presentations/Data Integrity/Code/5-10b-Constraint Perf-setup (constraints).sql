--the table structure.  

USE [HowToImplementDataIntegrity]
go

IF EXISTS ( SELECT  *
            FROM    sys.tables
            WHERE   OBJECT_ID = OBJECT_ID('Demo.[HighlyFormattedData]') ) 
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

