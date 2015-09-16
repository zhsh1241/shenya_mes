
insert into sys_codemstr
select 'TraceTable','系统数据追溯表',0 union all
select 'OperatorType','操作类型',0 
go

insert into sys_codedet(Code,Value,Desc1,IsDefault,Seq)
select 'TraceTable','ACC_Role','TraceTable_ACC_Role',1,0 union all
select 'TraceTable','ACC_RolePermissionGroup','TraceTable_ACC_RolePermissionGroup',0,1 union all
select 'TraceTable','ACC_User','TraceTable_ACC_User',0,2 union all
select 'TraceTable','ACC_UserPermission','TraceTable_ACC_UserPermission',0,3 union all
select 'TraceTable','ACC_UserPermissionGroup','TraceTable_ACC_UserPermissionGroup',0,4 union all
select 'TraceTable','ACC_UserRole','TraceTable_ACC_UserRole',0,5 union all
select 'TraceTable','SYS_EntityPreference','TraceTable_SYS_EntityPreference',0,6 union all
select 'OperatorType','CREATE','OperatorType_CREATE',1,0 union all
select 'OperatorType','UPDATE','OperatorType_UPDATE',0,1 union all
select 'OperatorType','DELETE','OperatorType_DELETE',0,2
go


insert into sys_menu 
select 'Url_TraceLog_View','系统数据追溯','Menu.Application',880000000,'应用管理-系统数据追溯','~/TraceLog/Index','~/Content/Images/Nav/Default.png',1
go

insert into ACC_Permission(Code,Desc1,Category,Sequence)
select 'Url_TraceLog_View','应用管理-系统数据追溯','Menu_Application',880000000
go






DROP PROCEDURE [dbo].[USP_Help_FormatLog]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[USP_Help_FormatLog]
AS
BEGIN
	DECLARE @MinRow int,@MaxRow int,@i int
	--UPDATE Sys_TraceLog SET IsUpdated=1 WHERE IsUpdated=0 AND Operator<>'UPDATE'
	SELECT RowId=ROW_NUMBER()OVER(ORDER BY OperateDate ASC),* INTO #Temp FROM Sys_TraceLog WHERE IsUpdated=0 AND Operator='UPDATE'
	IF @@ROWCOUNT>0
	BEGIN
		SELECT @MinRow=MIN(RowId),@MaxRow=MAX(RowId) FROM #Temp
		SET @i=@minRow
		WHILE(@i<=@maxRow)
		BEGIN
			DECLARE @LogId int
			SELECT @LogId=Id FROM #Temp WHERE RowId=@i
			print @LogId 
			DECLARE @OldMstrId int=0
			print @OldMstrId
			SELECT TOP 1 @OldMstrId=tl.Id FROM Sys_TraceLog i 
			INNER JOIN Sys_TraceLog tl
				ON i.Entity=tl.Entity AND i.Key1=tl.Key1 AND i.Id>tl.Id
			WHERE i.Id=@LogId ORDER BY tl.OperateDate DESC
			print @OldMstrId
			IF @OldMstrId<>0
			BEGIN
				PRINT '111111'
				UPDATE tld1 SET tld1.OldValue=tld2.NewValue FROM Sys_TraceLogDet tld1 INNER JOIN Sys_TraceLogDet tld2
					ON tld1.Field=tld2.Field AND tld1.NewValue<>tld2.NewValue
				INNER JOIN Sys_TraceLog tl ON tld2.TraceLogId=tl.Id
				INNER JOIN Sys_TraceLog i ON tld1.TraceLogId=i.Id
				WHERE i.Id=@LogId AND tl.Id=@OldMstrId
				
				DELETE tld FROM Sys_TraceLogDet tld INNER JOIN Sys_TraceLog i ON tld.TraceLogId=i.Id
				WHERE tld.OldValue is null AND i.Id=@LogId 
			END	
			UPDATE Sys_TraceLog SET IsUpdated=1 WHERE Id=@LogId
			SET @i=@i+1	
		END
	END		
END

GO



