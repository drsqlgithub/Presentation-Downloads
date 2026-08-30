--getting the children of a row (or ancestors with slight mod to query)
DECLARE @companyId int = (select companyId from corporate.company where parentCompanyId is null);

;WITH companyHierarchy(companyId, parentCompanyId, treelevel, hierarchy)
AS
(
     --gets the top level in hierarchy we want. The hierarchy column
     --will show the row's place in the hierarchy from this query only
     --not in the overall reality of the row's place in the table
     SELECT companyID, parentCompanyId,
            1 as treelevel, CAST(companyId as varchar(max)) as hierarchy
     FROM   corporate.company
     WHERE companyId=@CompanyId

     UNION ALL

     --joins back to the CTE to recursively retrieve the rows 
     --note that treelevel is incremented on each iteration
     SELECT company.companyID, company.parentCompanyId,
            treelevel + 1 as treelevel,
            hierarchy + '\' +cast(company.companyId as varchar(20)) as hierarchy
     FROM   corporate.company
              INNER JOIN companyHierarchy
                --use to get children, since the parentCompanyId of the child will be set the value
				--of the current row
                on company.parentCompanyId= companyHierarchy.companyID 
                --use to get parents, since the parent of the companyHierarchy row will be the company, 
				--not the parent.
                --on company.CompanyId= companyHierarchy.parentcompanyID
)
--return results from the CTE, joining to the company data to get the 
--company name
SELECT  company.companyID,company.name,
        companyHierarchy.treelevel, companyHierarchy.hierarchy
FROM     corporate.company
         INNER JOIN companyHierarchy
              ON company.companyID = companyHierarchy.companyID
ORDER BY hierarchy ;
GO

----------------------------------------


SELECT companyId, companyOrgNode.GetLevel() as level,
       name, companyOrgNode.ToString() as hierarchy 
FROM   corporate.companyHierarchyId
ORDER BY hierarchy

----------------------------------------

select *
from   corporate.companyPathMethod
order by path


-----------------------------------------

select *, case when hierarchyLeft = hierarchyRight -1 then 1 else 0 end as leafNodeFlag
from   corporate.companyNestedSets
order by hierarchyLeft
GO