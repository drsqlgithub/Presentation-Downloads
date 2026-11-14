use tempdb
go	
/*
Driver              Car Style                    Car Brand
------------------- ---------------------------- ----------------
Louis               Station Wagon                 Ford
Louis               Sedan                         Hyundai
Ted                 Coupe                         Chevrolet

Broken down into three tables:

Driver              Car Style                    
------------------- ----------------------------
Louis               Station Wagon               
Louis               Sedan
Ted                 Coupe

Driver              Car Brand
------------------- ----------------
Louis               Ford
Louis               Hyundai
Ted                 Chevrolet

Car Style                     Car Brand
----------------------------  ----------------
Station Wagon                 Ford
Sedan                         Hyundai
Coupe                         Chevrolet
*/
drop table driverCarStyle, driverCarBrand,CarBrandCarStyle
go
CREATE TABLE driverCarStyle
(
	Driver	VARCHAR(20),
	CarStyle VARCHAR(20),
	PRIMARY KEY (Driver,CarStyle)
)
INSERT INTO driverCarStyle (Driver, CarStyle)
VALUES ('Louis', 'Station Wagon'), ('Louis','Sedan'),('Ted','Coupe')


CREATE TABLE driverCarBrand
(
	Driver	VARCHAR(20),
	CarBrand VARCHAR(20),
	PRIMARY KEY (Driver,CarBrand)
)

INSERT INTO driverCarBrand (Driver, CarBrand)
VALUES ('Louis', 'Ford'), ('Louis','Hyundai'),('Ted','Chevrolet')

CREATE TABLE CarBrandCarStyle
(
	CarBrand	VARCHAR(20),
	CarStyle    VARCHAR(20),
	PRIMARY KEY (CarBrand, CarStyle)
)
INSERT INTO CarBrandCarStyle (CarBrand, CarStyle)
VALUES('Ford', 'Station Wagon'), ('Hyundai','Sedan'),('Chevrolet','Coupe')

/*
Driver              Car Style                    Car Brand
------------------- ---------------------------- ----------------
Louis               Station Wagon                 Ford
Louis               Sedan                         Hyundai
Ted                 Coupe                         Chevrolet
*/

SELECT DriverCarBrand.Driver, DriverCarBrand.CarBrand, DriverCarStyle.CarStyle
FROM   DriverCarBrand
		 JOIN DriverCarStyle
		    ON DriverCarBrand.Driver = DriverCarStyle.Driver
		 JOIN CarBrandCarStyle
			ON DriverCarBrand.CarBrand = CarBrandCarStyle.CarBrand
			   AND DriverCarStyle.CarStyle = carBrandCarStyle.CarStyle
go
INSERT INTO CarBrandCarStyle (CarBrand, CarStyle)
VALUES('Ford', 'Sedan')
go
SELECT DriverCarBrand.Driver, DriverCarBrand.CarBrand, DriverCarStyle.CarStyle
FROM   DriverCarBrand
		 JOIN DriverCarStyle
		    ON DriverCarBrand.Driver = DriverCarStyle.Driver
		 JOIN CarBrandCarStyle
			ON DriverCarBrand.CarBrand = CarBrandCarStyle.CarBrand
			   AND DriverCarStyle.CarStyle = carBrandCarStyle.CarStyle
Go