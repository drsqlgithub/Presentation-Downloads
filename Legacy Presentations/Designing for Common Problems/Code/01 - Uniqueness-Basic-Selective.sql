use master
Go

--drop db if you are recreating it, dropping all connections to existing database.
if exists (select * from sys.databases where name = 'Patterns_Uniqueness')
 exec ('
alter database  Patterns_Uniqueness
	set single_user with rollback immediate;

drop database Patterns_Uniqueness;')

create database Patterns_Uniqueness;
GO

Use Patterns_Uniqueness
go

/********************

Basic Uniqueness: Employee Number (every employee has one)

Selective Uniqueness: Insurance Policy Number (not every employee has one)

*********************/

CREATE SCHEMA HumanResources;
GO
CREATE TABLE HumanResources.employee
(
    EmployeeId int NOT NULL identity(1,1) constraint PKalt_employee primary key,
    EmployeeNumber char(5) NOT NULL
           CONSTRAINT AKalt_employee_employeeNummer UNIQUE,
    --skipping other columns you would likely have
    InsurancePolicyNumber char(10) NULL
);

Go

--Filtered Alternate Key (AKF Prefix)
CREATE UNIQUE INDEX AKFAccount_Contact_PrimaryContact ON
                                    HumanResources.employee(InsurancePolicyNumber)
WHERE InsurancePolicyNumber IS NOT NULL;
GO



INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0001','1111111111');
GO

INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0002','1111111111');
GO

INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0002',NULL);
GO



--always test multiple
INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0003','2222222222'),
       ('A0004','3333333333'),
       ('A0005',NULL),
	   ('A0006',NULL);
GO
INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0007','4444444444'),
       ('A0008','4444444444'),
       ('A0009','5555555555');
GO
SELECT *
FROM   HumanResources.Employee;
GO

/********************

Selective Uniqueness: Only one primary contact

*********************/

CREATE SCHEMA Account;
GO
CREATE TABLE Account.Contact
(
    AccountNumber   char(5) not null, --would be FK in full example
    ContactId   varchar(10) not null,
    PrimaryContactFlag bit not null,
    CONSTRAINT PKalt_accountContact
        PRIMARY KEY(AccountNumber, ContactId)
);

GO
CREATE UNIQUE INDEX
    AKFAccount_Contact_PrimaryContact
            ON Account.Contact(AccountNumber)
            WHERE PrimaryContactFlag = 1;

GO

INSERT INTO Account.Contact (AccountNumber, ContactId, PrimaryContactFlag)
SELECT '11111','bob',1;
GO
INSERT INTO Account.Contact(AccountNumber, ContactId, PrimaryContactFlag)
SELECT '11111','fred',1;
GO

select *
from   Account.Contact

--error handling not show for brevity
BEGIN TRANSACTION;

UPDATE Account.Contact
SET primaryContactFlag = 0
WHERE  accountNumber = '11111';

INSERT INTO Account.Contact(AccountNumber, ContactId, PrimaryContactFlag)
SELECT '11111','fred',1;

COMMIT TRANSACTION;
GO

select *
from   Account.Contact

--consider checking your work...because errors happen!
BEGIN TRANSACTION;

UPDATE Account.Contact
SET primaryContactFlag = 0
WHERE  accountNumber = '22222';

INSERT INTO Account.Contact(AccountNumber, ContactId, PrimaryContactFlag)
SELECT '22222','barney',0;

COMMIT TRANSACTION;
GO

--build consistency checking code for business rules that do not have constraints to implement them
select *
from   Account.Contact
where  not exists (	select *
					from   Account.Contact as CheckMe
					where  Contact.AccountNumber = CheckMe.AccountNumber
					  and  PrimaryContactFlag = 1)



UPDATE Account.Contact
SET primaryContactFlag = 1
WHERE  accountNumber = '22222';



select *
from   Account.Contact

-------------------------------------------------
--pre-2008 example

DROP INDEX AKFAccount_Contact_PrimaryContact ON
                                    HumanResources.employee
GO
CREATE VIEW HumanResources.Employee_InsurancePolicyNumberUniqueness
WITH SCHEMABINDING
AS
SELECT InsurancePolicyNumber
FROM HumanResources.Employee
WHERE InsurancePolicyNumber IS NOT NULL;
GO

CREATE UNIQUE CLUSTERED INDEX
AKHumanResources_Employee_InsurancePolicyNumberUniqueness
ON HumanResources.Employee_InsurancePolicyNumberUniqueness(InsurancePolicyNumber);
GO

INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0010','1111111111');
GO
INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0011','4444444444');
GO

INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0012','5555555555'),
	   ('A0013',NULL),
	   ('A0014',NULL),
	   ('A0015','6666666666')
GO

select *
from   HumanResources.Employee