****************************************************************************
--Query 1
-- Amount of parking reports by Borough in New York City from 2015 to 2017 
****************************************************************************
SELECT b.BoroughName,count(f.ParkingViolationKey) AS Num_of_violations
FROM  dbo.DimBorough b join dbo.DimLocation l
ON b.BoroughCode=l.BoroughCode
 join dbo.FactParkingViolation f
ON f.LocationKey= l.LocationKey
WHERE datepart(year,f.IssueDate) between 2015 and 2017
GROUP BY b.BoroughName 
ORDER BY Num_of_violations DESC

*************************************************************************
--Stored Procedure 1  with a parameter of the name of the district
*************************************************************************
create procedure sp_Num_of_violations
@BoroughName varchar (20)
AS
BEGIN
      SELECT b.BoroughName,count(f.ParkingViolationKey) AS Num_of_violations
      FROM  dbo.DimBorough b join dbo.DimLocation l
      ON b.BoroughCode=l.BoroughCode
      join dbo.FactParkingViolation f
      ON f.LocationKey= l.LocationKey
     WHERE b.BoroughName=@BoroughName and datepart(year,f.IssueDate) between 2015 and 2017
     GROUP BY b.BoroughName 
ORDER BY Num_of_violations DESC

END

EXEC sp_Num_of_violations @BoroughName=Bronx

********************************************************************************************
--Query 2
-- Displaing the amount of parking reports for each district and for every day of week

********************************************************************************************
SELECT b.BoroughName,datename(weekday,f.IssueDate) AS Day_of_week,count(f.ParkingViolationKey) AS Num_of_violations
FROM  dbo.DimBorough b join dbo.DimLocation l
ON b.BoroughCode=l.BoroughCode
 join dbo.FactParkingViolation f
ON f.LocationKey= l.LocationKey
WHERE datepart(year,f.IssueDate) between 2015 and 2017
GROUP BY b.BoroughName, datename(weekday,f.IssueDate)
ORDER BY Num_of_violations DESC

*****************************************************************
--Stored Procedure 2 with a parameter of the day of week
*****************************************************************
create procedure sp_violations_count_by_weekday
@dayofweek varchar(20)
AS
BEGIN
    SELECT b.BoroughName,datename(weekday,f.IssueDate) AS Day_of_week,count(f.ParkingViolationKey) AS Num_of_violations
    FROM  dbo.DimBorough b join dbo.DimLocation l
    ON b.BoroughCode=l.BoroughCode
    join dbo.FactParkingViolation f
    ON f.LocationKey= l.LocationKey
    WHERE datename(weekday,f.IssueDate)=@dayofweek AND datepart(year,f.IssueDate) between 2015 and 2017
   GROUP BY b.BoroughName, datename(weekday,f.IssueDate)
   ORDER BY Num_of_violations DESC
END

exec sp_violations_count_by_weekday @dayofweek=Monday

**************************************************************************************
--Query 3
--The five types of parking violations, according to the ViolationCode, 
--are the most common in the years 2015 to 2017
******************************************************************************************

select TOP 5 ViolationCode,count(ViolationCode) AS Num_of_violationcode
from FactParkingViolation 
where datepart(year,IssueDate) between 2015 and 2017
group by ViolationCode
order by count(ViolationCode) DESC

*********************************************************************************************
--Stored procedure 3
*********************************************************************************************
create procedure sp_Num_of_violationcode
@maxviolation int
AS
BEGIN
      
     select Top ( @maxviolation) ViolationCode,count(ViolationCode) AS Num_of_violationcode
     from FactParkingViolation 
     where datepart(year,IssueDate) between 2015 and 2017
     group by ViolationCode
     order by count(ViolationCode) DESC
END

EXEC sp_Num_of_violationcode  @maxviolation = 10

*********************************************************************************************
--Query 4
-- The two most common types of violations for each vehicle color , excluding unknown color

*********************************************************************************************

SELECT colorname,violationcode
FROM
(SELECT colorname,violationcode,ROW_NUMBER() OVER( PARTITION BY colorname ORDER BY num_of_violations DESC) AS ROW_NUM
FROM
(SELECT  c.colorname,f.violationcode, count(f.violationcode)  AS num_of_violations
FROM  dimvehicle v join dimcolor c
ON v.VehicleColorCode=c.colorcode
join FactParkingViolation f
ON f.vehiclekey=v.vehiclekey
WHERE c.colorname!='Unknown' and datepart(year,f.IssueDate) between 2015 and 2017  
GROUP BY c.colorname,f.violationcode) AS violations_count) AS NUM_ROW
WHERE ROW_NUM <=2


*********************************************************************************
--Stored procedure  4
*********************************************************************************
create procedure sp_violation_color
@max_violations_by_color int
AS
BEGIN
		SELECT colorname,violationcode
		FROM
		(SELECT colorname,violationcode, ROW_NUMBER() OVER( PARTITION BY colorname ORDER BY num_of_violations DESC) AS ROW_NUM
		FROM
		(SELECT  c.colorname,f.violationcode, count(f.violationcode)  AS num_of_violations
		FROM  dimvehicle v join dimcolor c
		ON v.VehicleColorCode=c.colorcode
		join FactParkingViolation f
		ON f.vehiclekey=v.vehiclekey
		WHERE c.colorname!='Unknown' and datepart(year,f.IssueDate) between 2015 and 2017  
		GROUP BY c.colorname,f.violationcode) AS violations_count) AS NUM_ROW
		WHERE ROW_NUM <= (@max_violations_by_color)

END
    
EXEC sp_violation_color  @max_violations_by_color = 5

*********************************************************************
--Qery 5
--the number of vehicles that received parking reports between 
--the years 2015 and 2017 according to groups of:
-- 10 or more
-- between 5 and 9
--below 5
*********************************************************************
SELECT  violation_group,COUNT(VehicleKey) AS vehicle_count
FROM
(SELECT 
      CASE 
	       WHEN violation_count >=10 THEN '10 or more'
		   WHEN violation_count BETWEEN 5 AND 9 THEN 'between 5 and 9'
		   ELSE 'below 5'
		   END violation_group,VehicleKey
FROM
(SELECT VehicleKey,count(ParkingViolationKey) AS violation_count
FROM FactParkingViolation
WHERE datepart(year,IssueDate) between 2015 and 2017
GROUP BY VehicleKey) AS vehicle_violations) AS violation_groups
GROUP BY violation_group
ORDER BY vehicle_count


******************************************************************
--Query 6
--columns for each country where the vehicle is registered
--The percentage change in the amount of parking reports between the year 2017 and the year 2015
******************************************************************

SELECT StateName, violations_2015,violations_2016,violations_2017,
       CASE 
	        WHEN violations_2015 = 0 THEN NULL
			ELSE cast(cast(((violations_2017 - violations_2015) * 100.0 / violations_2015) AS decimal(10,2)) as varchar(10)) + '%'
			END pct_difference_2017_2015
FROM
(SELECT s.StateName,
       SUM( CASE  WHEN datepart(year,f.IssueDate) =2015 THEN 1 ELSE 0 END) AS violations_2015,
	   SUM(CASE WHEN datepart(year,f.IssueDate) =2016 THEN 1 ELSE 0 END ) AS violations_2016,
	   SUM(CASE  WHEN datepart(year,f.IssueDate) =2017 THEN 1 ELSE 0 END) AS violations_2017                           
FROM FactParkingViolation f JOIN DimVehicle v
     ON f.VehicleKey=v.VehicleKey
	 JOIN DimState s 
	 ON v.RegistrationStateCode=s.StateCode
WHERE datepart(year,f.IssueDate) BETWEEN 2015 AND 2017
GROUP BY s.StateName
) as total_yearly








