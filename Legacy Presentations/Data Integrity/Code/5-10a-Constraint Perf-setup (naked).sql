--the table structure.  

USE HowToImplementDataIntegrity
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



