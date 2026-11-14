---After trigger template

CREATE TRIGGER <schema>.<table>$<actions>Trigger
ON <schema>.<table>
AFTER <comma delimited actions> AS 
BEGIN
   IF @@rowcount = 0 RETURN; --if no rows affected by calling DML statement, exit

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM INSERTED);
   --      @rowsAffected int = (SELECT COUNT(*) FROM DELETED);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;
   
   BEGIN TRY
          --[validation section] In this section, you should just look for issues and THROW errors

          --[modification section] In this section, the goal is no errors and do any data mods here
	      
   END TRY
   BEGIN CATCH
		IF @@trancount > 0
			ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

		--[Error logging section] In this section, log any errors because you are outside of the transaction
						--due to the rollback
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
		        @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
		        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

		THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO


--instead of trigger template

CREATE TRIGGER <schema>.<tablename>$InsteadOf<actions>Trigger
ON <schema>.<tablename>
INSTEAD OF <comma delimited actions> AS
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
		  --                       here. 

          --<perform action>  In this section (generally the only one used in an instead of trigger), you
		                    --will usually cause the operation replaced by the trigger to occur
						
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION; --make sure to use semicolons to prevent THROW from being treated as a savepoint

      --[Error logging section]
		DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
		        @ERROR_LOCATION sysname = ERROR_PROCEDURE(),
		        @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
		EXEC Utility.ErrorLog$Insert @ERROR_NUMBER,@ERROR_LOCATION,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO


