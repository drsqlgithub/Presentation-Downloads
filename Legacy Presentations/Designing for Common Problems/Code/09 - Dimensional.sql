--Adapted from code by Jessica Moss for 
--Pro SQL Server 2012 Relational Database Design and Implementation

USE master
Go
SET NOCOUNT ON
--drop db if you are recreating it, dropping all connections to existing database.
IF EXISTS ( SELECT  *
            FROM    sys.databases
            WHERE   name = 'Patterns_Dimensional' ) 
    EXEC ('
    alter database Patterns_Dimensional
    set single_user with rollback immediate;

    drop database Patterns_Dimensional;')

CREATE DATABASE Patterns_Dimensional
go
-- Use the ReportDesign database
USE Patterns_Dimensional
GO

-- Create schema for all dimension tables
CREATE SCHEMA dim
GO

-- Create Date Dimension
CREATE TABLE dim.Date
    (
      DateKey INTEGER NOT NULL ,
      DateValue DATE NOT NULL ,
      DayValue INTEGER NOT NULL ,
      WeekValue INTEGER NOT NULL ,
      MonthValue INTEGER NOT NULL ,
      YearValue INTEGER
        NOT NULL CONSTRAINT PK_Date PRIMARY KEY CLUSTERED ( DateKey ASC )
    )
GO

-- Create Date Dimension Load Stored Precedure
CREATE PROCEDURE dim.LoadDate
    (
      @startDate DATETIME ,
      @endDate DATETIME
    )
AS 
    BEGIN

        IF NOT EXISTS ( SELECT  *
                        FROM    dim.Date
                        WHERE   DateKey = -1 ) 
            BEGIN
                INSERT  INTO dim.Date
                        SELECT  -1 ,
                                '01/01/1900' ,
                                -1 ,
                                -1 ,
                                -1 ,
                                -1
            END

        WHILE @startdate <= @enddate 
            BEGIN
                IF NOT EXISTS ( SELECT  *
                                FROM    dim.Date
                                WHERE   DateValue = @startdate ) 
                    INSERT  INTO dim.Date
                            SELECT  CONVERT(CHAR(8), @startdate, 112) AS DateKey ,
                                    @startdate AS DateValue ,
                                    DAY(@startdate) AS DayValue ,
                                    DATEPART(wk, @startdate) AS WeekValue ,
                                    MONTH(@startdate) AS MonthValue ,
                                    YEAR(@startdate) AS YearValue
                SET @startdate = DATEADD(dd, 1, @startdate)
            END
    END
GO

EXECUTE dim.LoadDate '01/01/2011', '12/31/2012'
GO


-- Create the Member dimension table
CREATE TABLE dim.Member
    (
      MemberKey INTEGER NOT NULL
                        IDENTITY(1, 1) ,
      InsuranceNumber VARCHAR(12) NOT NULL ,
      FirstName VARCHAR(50) NOT NULL ,
      LastName VARCHAR(50) NOT NULL ,
      PrimaryCarePhysician VARCHAR(100) NOT NULL ,
      County VARCHAR(40) NOT NULL ,
      StateCode CHAR(2) NOT NULL ,
      MembershipLength VARCHAR(15)
        NOT NULL CONSTRAINT PK_Member PRIMARY KEY CLUSTERED ( MemberKey ASC )
    )
GO

-- Load Member dimension table
SET IDENTITY_INSERT [dim].[Member] ON
GO
INSERT  INTO [dim].[Member]
        ( [MemberKey] ,
          [InsuranceNumber] ,
          [FirstName] ,
          [LastName] ,
          [PrimaryCarePhysician] ,
          [County] ,
          [StateCode] ,
          [MembershipLength]
        )
VALUES  ( -1 ,
          'UNKNOWN' ,
          'UNKNOWN' ,
          'UNKNOWN' ,
          'UNKNOWN' ,
          'UNKNOWN' ,
          'UN' ,
          'UNKNOWN'
        )
GO
SET IDENTITY_INSERT [dim].[Member] OFF
GO
INSERT  INTO [dim].[Member]
        ( [InsuranceNumber] ,
          [FirstName] ,
          [LastName] ,
          [PrimaryCarePhysician] ,
          [County] ,
          [StateCode] ,
          [MembershipLength]
        )
VALUES  ( 'IN438973' ,
          'Brandi' ,
          'Jones' ,
          'Dr. Keiser & Associates' ,
          'Henrico' ,
          'VA' ,
          '<1 year'
        )
GO
INSERT  INTO [dim].[Member]
        ( [InsuranceNumber] ,
          [FirstName] ,
          [LastName] ,
          [PrimaryCarePhysician] ,
          [County] ,
          [StateCode] ,
          [MembershipLength]
        )
VALUES  ( 'IN958394' ,
          'Neil' ,
          'Gomez' ,
          'Healthy Lifestyles' ,
          'Henrico' ,
          'VA' ,
          '1-2 year'
        )
GO
INSERT  INTO [dim].[Member]
        ( [InsuranceNumber] ,
          [FirstName] ,
          [LastName] ,
          [PrimaryCarePhysician] ,
          [County] ,
          [StateCode] ,
          [MembershipLength]
        )
VALUES  ( 'IN3867910' ,
          'Catherine' ,
          'Patten' ,
          'Dr. Jenny Stevens' ,
          'Spotsylvania' ,
          'VA' ,
          '<1 year'
        )
GO


ALTER TABLE dim.Member
ADD isCurrent INTEGER NOT NULL DEFAULT 1
GO

INSERT  INTO [dim].[Member]
        ( [InsuranceNumber] ,
          [FirstName] ,
          [LastName] ,
          [PrimaryCarePhysician] ,
          [County] ,
          [StateCode] ,
          [MembershipLength]
        )
VALUES  ( 'IN438973' ,
          'Brandi' ,
          'Jones' ,
          'Dr. Jenny Stevens' ,
          'Henrico' ,
          'VA' ,
          '<1 year'
        )
GO

UPDATE  [dim].[Member]
SET     isCurrent = 0
WHERE   InsuranceNumber = 'IN438973'
        AND PrimaryCarePhysician = 'Dr. Keiser & Associates'
GO

-- Create the Provider dimension table
CREATE TABLE dim.Provider
    (
      ProviderKey INTEGER IDENTITY(1, 1)
                          NOT NULL ,
      NPI VARCHAR(10) NOT NULL ,
      EntityTypeCode INTEGER NOT NULL ,
      EntityTypeDesc VARCHAR(12) NOT NULL , -- (1:Individual,2:Organization)
      OrganizationName VARCHAR(70) NOT NULL ,
      DoingBusinessAsName VARCHAR(70) NOT NULL ,
      Street VARCHAR(55) NOT NULL ,
      City VARCHAR(40) NOT NULL ,
      State VARCHAR(40) NOT NULL ,
      Zip VARCHAR(20) NOT NULL ,
      Phone VARCHAR(20) NOT NULL ,
      isCurrent INTEGER
        NOT NULL
        DEFAULT 1
        CONSTRAINT PK_Provider PRIMARY KEY CLUSTERED ( ProviderKey ASC )
    )
GO

-- Insert sample data into Provider dimension table
SET IDENTITY_INSERT [dim].[Provider] ON
GO
INSERT  INTO [dim].[Provider]
        ( [ProviderKey] ,
          [NPI] ,
          [EntityTypeCode] ,
          [EntityTypeDesc] ,
          [OrganizationName] ,
          [DoingBusinessAsName] ,
          [Street] ,
          [City] ,
          [State] ,
          [Zip] ,
          [Phone]
        )
VALUES  ( -1 ,
          'UNKNOWN' ,
          -1 ,
          'UNKNOWN' ,
          'UNKNOWN' ,
          'UNKNOWN' ,
          'UNKNOWN' ,
          'UNKNOWN' ,
          'UNKNOWN' ,
          'UNKNOWN' ,
          'UNKNOWN'
        )
GO
SET IDENTITY_INSERT [dim].[Provider] OFF
GO

INSERT  INTO [dim].[Provider]
        ( [NPI] ,
          [EntityTypeCode] ,
          [EntityTypeDesc] ,
          [OrganizationName] ,
          [DoingBusinessAsName] ,
          [Street] ,
          [City] ,
          [State] ,
          [Zip] ,
          [Phone]
        )
VALUES  ( '1234567' ,
          1 ,
          'Individual' ,
          'Patrick Lyons' ,
          'Patrick Lyons' ,
          '80 Park St.' ,
          'Boston' ,
          'Massachusetts' ,
          '55555' ,
          '555-123-1234'
        )
GO
INSERT  INTO [dim].[Provider]
        ( [NPI] ,
          [EntityTypeCode] ,
          [EntityTypeDesc] ,
          [OrganizationName] ,
          [DoingBusinessAsName] ,
          [Street] ,
          [City] ,
          [State] ,
          [Zip] ,
          [Phone]
        )
VALUES  ( '2345678' ,
          1 ,
          'Individual' ,
          'Lianna White, LLC' ,
          'Dr. White & Associates' ,
          '74 West Pine Ave.' ,
          'Waltham' ,
          'Massachusetts' ,
          '55542' ,
          '555-123-0012'
        )
GO
INSERT  INTO [dim].[Provider]
        ( [NPI] ,
          [EntityTypeCode] ,
          [EntityTypeDesc] ,
          [OrganizationName] ,
          [DoingBusinessAsName] ,
          [Street] ,
          [City] ,
          [State] ,
          [Zip] ,
          [Phone]
        )
VALUES  ( '76543210' ,
          2 ,
          'Organization' ,
          'Doctors Conglomerate, Inc' ,
          'Family Doctors' ,
          '25 Main Street Suite 108' ,
          'Boston' ,
          'Massachusetts' ,
          '55555' ,
          '555-321-4321'
        )
GO
INSERT  INTO [dim].[Provider]
        ( [NPI] ,
          [EntityTypeCode] ,
          [EntityTypeDesc] ,
          [OrganizationName] ,
          [DoingBusinessAsName] ,
          [Street] ,
          [City] ,
          [State] ,
          [Zip] ,
          [Phone]
        )
VALUES  ( '3456789' ,
          1 ,
          'Individual' ,
          'Dr. Drew Adams' ,
          'Dr. Drew Adams' ,
          '1207 Corporate Center' ,
          'Peabody' ,
          'Massachusetts' ,
          '55554' ,
          '555-234-1234'
        )
GO

-- Create the Benefit dimension table
CREATE TABLE dim.Benefit
    (
      BenefitKey INTEGER IDENTITY(1, 1)
                         NOT NULL ,
      BenefitCode INTEGER NOT NULL ,
      BenefitName VARCHAR(35) NOT NULL ,
      BenefitSubtype VARCHAR(20) NOT NULL ,
      BenefitType VARCHAR(20)
        NOT NULL
        CONSTRAINT PK_Benefit PRIMARY KEY CLUSTERED ( BenefitKey ASC )
    )
GO

-- Create the Health Plan dimension table
CREATE TABLE dim.HealthPlan
    (
      HealthPlanKey INTEGER IDENTITY(1, 1)
                            NOT NULL ,
      HealthPlanIdentifier CHAR(4) NOT NULL ,
      HealthPlanName VARCHAR(35)
        NOT NULL
        CONSTRAINT PK_HealthPlan PRIMARY KEY CLUSTERED ( HealthPlanKey ASC )
    )
GO

ALTER TABLE dim.Benefit
ADD HealthPlanKey INTEGER
GO

ALTER TABLE dim.Benefit  WITH CHECK
ADD CONSTRAINT FK_Benefit_HealthPlan
FOREIGN KEY(HealthPlanKey) REFERENCES dim.HealthPlan (HealthPlanKey) 
GO

-- Insert sample data into Health plan dimension
INSERT  INTO [dim].[HealthPlan]
        ( [HealthPlanIdentifier] ,
          [HealthPlanName]
        )
VALUES  ( 'BRON' ,
          'Bronze Plan'
        )
GO
INSERT  INTO [dim].[HealthPlan]
        ( [HealthPlanIdentifier] ,
          [HealthPlanName]
        )
VALUES  ( 'SILV' ,
          'Silver Plan'
        )
GO
INSERT  INTO [dim].[HealthPlan]
        ( [HealthPlanIdentifier] ,
          [HealthPlanName]
        )
VALUES  ( 'GOLD' ,
          'Gold Plan'
        )
GO

-- Create the AdjudicationType dimension table
CREATE TABLE dim.AdjudicationType
    (
      AdjudicationTypeKey INTEGER IDENTITY(1, 1)
                                  NOT NULL ,
      AdjudicationType VARCHAR(6) NOT NULL ,
      AdjudicationCategory VARCHAR(8)
        NOT NULL
        CONSTRAINT PK_AdjudicationType
        PRIMARY KEY CLUSTERED ( AdjudicationTypeKey ASC )
    )
GO

-- Insert values for the AdjudicationType dimension
SET IDENTITY_INSERT dim.AdjudicationType ON
GO
INSERT  INTO dim.AdjudicationType
        ( AdjudicationTypeKey ,
          AdjudicationType ,
          AdjudicationCategory
        )
VALUES  ( -1 ,
          'UNKNWN' ,
          'UNKNOWN'
        )
INSERT  INTO dim.AdjudicationType
        ( AdjudicationTypeKey ,
          AdjudicationType ,
          AdjudicationCategory
        )
VALUES  ( 1 ,
          'AUTO' ,
          'ACCEPTED'
        )
INSERT  INTO dim.AdjudicationType
        ( AdjudicationTypeKey ,
          AdjudicationType ,
          AdjudicationCategory
        )
VALUES  ( 2 ,
          'MANUAL' ,
          'ACCEPTED'
        )
INSERT  INTO dim.AdjudicationType
        ( AdjudicationTypeKey ,
          AdjudicationType ,
          AdjudicationCategory
        )
VALUES  ( 3 ,
          'DENIED' ,
          'DENIED'
        )
GO
SET IDENTITY_INSERT dim.AdjudicationType OFF
GO

-- Create Diagnosis dimension table
CREATE TABLE dim.Diagnosis
    (
      DiagnosisKey INT IDENTITY(1, 1)
                       NOT NULL ,
      DiagnosisCode CHAR(7) NULL ,
      ShortDesc VARCHAR(60) NULL ,
      LongDesc VARCHAR(322) NULL ,
      OrderNumber INT NULL ,
      CONSTRAINT PK_Diagnosis PRIMARY KEY CLUSTERED ( DiagnosisKey ASC )
    )
GO
INSERT  INTO dim.Diagnosis
        ( DiagnosisCode, ShortDesc, LongDesc, OrderNumber )
VALUES  ( 'HACHE', 'Head Ache', 'Head Ache', 1 ),
        ( 'CFUSE', 'Confusion', 'Confusion', 2 ),
        ( 'NBLD', 'Nose Bleed', 'Nose Bleed', 3 ),
        ( 'HDF', 'Hot Dog Fingers', 'Hot Dog Fingers', 4 )
GO

---- Create HCPCSProcedure dimension table
--CREATE TABLE dim.HCPCSProcedure (
--	ProcedureKey INTEGER IDENTITY(1,1) NOT NULL,
--	ProcedureCode CHAR(5) NOT NULL,
--	ShortDesc VARCHAR(28) NOT NULL,
--	LongDesc VARCHAR(80) NOT NULL
-- CONSTRAINT PK_HCPCSProcedure PRIMARY KEY CLUSTERED 
--(
--	ProcedureKey ASC
--))
--GO

-- Create schema for all fact tables
CREATE SCHEMA fact
GO

-- Create Claim Payment transaction fact table
CREATE TABLE fact.ClaimPayment
    (
      DateKey INTEGER NOT NULL ,
      MemberKey INTEGER NOT NULL ,
      AdjudicationTypeKey INTEGER NOT NULL ,
      ProviderKey INTEGER NOT NULL ,
      DiagnosisKey INTEGER NOT NULL ,
	--ProcedureKey INTEGER NOT NULL,
      ClaimID VARCHAR(8) NOT NULL ,
      ClaimAmount DECIMAL(10, 2) NOT NULL ,
      AutoPayoutAmount DECIMAL(10, 2) NOT NULL ,
      ManualPayoutAmount DECIMAL(10, 2) NOT NULL ,
      AutoAdjudicatedCount INTEGER NOT NULL ,
      ManualAdjudicatedCount INTEGER NOT NULL ,
      DeniedCount INTEGER NOT NULL
    )
GO

-- Add foreign keys from ClaimPayment fact to dimensions
ALTER TABLE fact.ClaimPayment  WITH CHECK 
ADD CONSTRAINT FK_ClaimPayment_AdjudicationType
FOREIGN KEY(AdjudicationTypeKey) REFERENCES dim.AdjudicationType (AdjudicationTypeKey)
GO

ALTER TABLE fact.ClaimPayment  WITH CHECK 
ADD CONSTRAINT FK_ClaimPayment_Date
FOREIGN KEY(DateKey) REFERENCES dim.Date (DateKey)
GO

ALTER TABLE fact.ClaimPayment  WITH CHECK 
ADD CONSTRAINT FK_ClaimPayment_Diagnosis
FOREIGN KEY(DiagnosisKey) REFERENCES dim.Diagnosis (DiagnosisKey)
GO

--ALTER TABLE fact.ClaimPayment  WITH CHECK 
--ADD CONSTRAINT FK_ClaimPayment_HCPCSProcedure
--FOREIGN KEY(ProcedureKey) REFERENCES dim.HCPCSProcedure (ProcedureKey)
--GO

ALTER TABLE fact.ClaimPayment  WITH CHECK 
ADD CONSTRAINT FK_ClaimPayment_Member
FOREIGN KEY(MemberKey) REFERENCES dim.Member (MemberKey)
GO

ALTER TABLE fact.ClaimPayment  WITH CHECK 
ADD CONSTRAINT FK_ClaimPayment_Provider
FOREIGN KEY(ProviderKey) REFERENCES dim.Provider (ProviderKey)
GO


-- Insert sample data into ClaimPayment fact table
DECLARE @i INT
SET @i = 0
WHILE @i < 1000 
    BEGIN
        INSERT  INTO fact.ClaimPayment
                ( DateKey ,
                  MemberKey ,
                  AdjudicationTypeKey ,
                  ProviderKey ,
                  DiagnosisKey ,
	--ProcedureKey, 
                  ClaimID ,
                  ClaimAmount ,
                  AutoPayoutAmount ,
                  ManualPayoutAmount ,
                  AutoAdjudicatedCount ,
                  ManualAdjudicatedCount ,
                  DeniedCount
                )
                SELECT  CONVERT(CHAR(8), DATEADD(dd, RAND() * -100, GETDATE()), 112) ,
                        ( SELECT    CEILING(( COUNT(*) - 1 ) * RAND())
                          FROM      dim.Member
                        ) ,
                        ( SELECT    CEILING(( COUNT(*) - 1 ) * RAND())
                          FROM      dim.AdjudicationType
                        ) ,
                        ( SELECT    CEILING(( COUNT(*) - 1 ) * RAND())
                          FROM      dim.Provider
                        ) ,
                        ( SELECT    CEILING(( COUNT(*) - 1 ) * RAND())
                          FROM      dim.Diagnosis
                        ) ,
	--(SELECT CEILING((COUNT(*) - 1) * RAND()) from dim.HCPCSProcedure),
                        'CL' + CAST(@i AS VARCHAR(6)) ,
                        RAND() * 100000 ,
                        RAND() * 100000 * ( @i % 2 ) ,
                        RAND() * 100000 * ( ( @i + 1 ) % 2 ) ,
                        @i % 2 ,
                        ( @i + 1 ) % 2 ,
                        0
        SET @i = @i + 1
    END
GO


SELECT  dd.MonthValue, dm.InsuranceNumber, dat.AdjudicationType ,
        dp.OrganizationName, ddiag.DiagnosisCode, 
        SUM(fcp.ClaimAmount) AS ClaimAmount ,
        SUM(fcp.AutoPayoutAmount) AS AutoPaymountAmount ,
        SUM(fcp.ManualPayoutAmount) AS ManualPayoutAmount ,
        SUM(fcp.AutoAdjudicatedCount) AS AutoAdjudicatedCount ,
        SUM(fcp.ManualAdjudicatedCount) AS ManualAdjudicatedCount ,
        SUM(fcp.DeniedCount) AS DeniedCount
FROM    fact.ClaimPayment fcp
        INNER JOIN dim.Date dd
            ON fcp.DateKey = dd.DateKey
        INNER JOIN dim.Member dm
            ON fcp.MemberKey = dm.MemberKey
        INNER JOIN dim.AdjudicationType dat
            ON fcp.AdjudicationTypeKey = dat.AdjudicationTypeKey
        INNER JOIN dim.Provider dp
            ON fcp.ProviderKey = dp.ProviderKey
        INNER JOIN dim.Diagnosis ddiag
            ON fcp.DiagnosisKey = ddiag.DiagnosisKey
WHERE   YearValue = 2012
GROUP BY dd.MonthValue ,
        dm.InsuranceNumber ,
        dat.AdjudicationType ,
        dp.OrganizationName ,
        ddiag.DiagnosisCode --, dhcpc.ProcedureCode
        WITH ROLLUP
ORDER BY dd.MonthValue ,
        dm.InsuranceNumber ,
        dat.AdjudicationType ,
        dp.OrganizationName ,
        ddiag.DiagnosisCode 
GO

