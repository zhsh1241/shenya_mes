
/****** Object:  StoredProcedure [dbo].[USP_Report_ShelfLifeWarning]    Script Date: 2015/9/10 10:33:38 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[USP_Report_ShelfLifeWarning] 
(
	@Location varchar(80),
	@Item varchar(80),
	@Type varchar(20),
	@PageSize int,
	@Page int

)
AS
BEGIN
    SELECT @Location=LTRIM(RTRIM(@Location)),@Item=LTRIM(RTRIM(@Item))
/*
exec USP_Report_ShelfLifeWarning '9101','200024','Summary' ,30,1 
500368184
*/
	/*2015/02/25  温祥永 保质期预警报表分类逻辑如下（各项内容不应该重复统计）：
					如果 当前时间> 物料制造日期+保质期 ， 属于“已过期”；
					如果 物料主数据 保质期 or 保质期预警期 = 0 ，属于“预警期外”；
					如果 当前时间< 物料制造日期+保质期-预警器， 属于“预警期外”；
					如果 物料制造日期+保质期-预警器 <= 当前时间 <= 物料制造日期+保质期， 属于“预警期内”
	*/
	SET NOCOUNT ON
	--条码	物料代码	参考物料号	描述	制造日期	单包装	单位	数量 	预警时间	过期时间	状态

	DECLARE @PagePara varchar(1000)=''
	Declare @CurrentDate datetime=getdate()
	select top 0 a.HuId,a.Item ,a.RefItemCode,a.ItemDesc,a.LotNo,a.LocTo Location,a.UC,a.Uom,a.Qty,a.Qty Qty0,a.Qty Qty1,a.Qty Qty2,a.RemindExpireDate,a.ExpireDate,CAST(0 As int) As RowID into #TempResult from INV_Hu a where 1=2
	If @Type = 'ByExpireTime'---已过期
		Begin
			Insert into #TempResult 
			select a.HuId,a.Item ,a.RefItemCode,a.ItemDesc ,a.LotNo,b.Location,a.UC,a.Uom,a.Qty,0,0,0, DATEADD(day,-c.WarnLeadTime,a.ExpireDate) , a.ExpireDate , 
				ROW_NUMBER()over(order by a.ExpireDate,a.item,a.lotno ) 
					As RowID from INV_Hu a with(nolock),VIEW_LocationLotDet b with(nolock),MD_Item c
					where a.HuId =b.HuId and a.Item=c.Code
					----Time compare logic
					and (a.ExpireDate <@CurrentDate and  a.ExpireDate is not null) 
					----Time compare logic
					and a.HuId is not null and
					a.Item like isnull(@Item,'')+'%' and b.Location like isnull(@Location,'')+'%' and c.Warranty!=0 and a.ExpireDate is not null
		End
	
	Else If @Type = 'ByOutOfExpireTime'---预警期外(按物料汇总)
		Begin
			Insert into #TempResult 
			select '' as  HuId,a.Item ,'' RefItemCode,a.ItemDesc ,'' LotNo,''Location,0 UC,0 Uom,sum(a.Qty) Qty,0,0,0,0 RemindExpireDate,0 ExpireDate,
				ROW_NUMBER()over(order by a.item) 
					As RowID from INV_Hu a with(nolock),VIEW_LocationLotDet b with(nolock),MD_Item c
					where a.HuId =b.HuId and a.Item=c.Code 
					and DATEADD(day,-c.WarnLeadTime,a.ExpireDate)>@CurrentDate
					----Time compare logic 
					--(a.RemindExpireDate is null or a.ExpireDate is null or 
					--(a.ExpireDate is not null  and a.RemindExpireDate is not null 
					--and DATEDIFF(day,a.ManufactureDate,@CurrentDate)+DATEDIFF(day,a.ExpireDate,RemindExpireDate)<0))
					----Time compare logic 
					and a.HuId is not null and
					a.Item like isnull(@Item,'')+'%' and b.Location like isnull(@Location,'')+'%' and c.Warranty!=0 and a.ExpireDate is not null
					Group by a.Item ,a.ItemDesc 
		End
	Else If @Type ='ByRemindExpireTime'----预警期内
		Begin
			Insert into #TempResult 
			select a.HuId,a.Item ,a.RefItemCode,a.ItemDesc,a.LotNo,b.Location,a.UC,a.Uom,a.Qty,0,0,0,  DATEADD(day,-c.WarnLeadTime,a.ExpireDate) , a.ExpireDate , 
				ROW_NUMBER()over(order by a.ExpireDate, a.item,a.lotno ) 
					As RowID from INV_Hu a with(nolock),VIEW_LocationLotDet b with(nolock) ,MD_Item c
					where a.HuId =b.HuId and a.Item=c.Code 
					and DATEADD(day,-c.WarnLeadTime,a.ExpireDate)<=@CurrentDate and @CurrentDate<a.ExpireDate
					----Time compare logic 
					--and (a.ExpireDate >@CurrentDate 
					--and DATEDIFF(day,a.ManufactureDate,@CurrentDate)
					--+DATEDIFF(day,a.ExpireDate,RemindExpireDate)>=0
					--and a.RemindExpireDate is not null and a.ExpireDate is not null )
					----Time compare logic 
					and a.HuId is not null and 
					a.Item like isnull(@Item,'')+'%' and b.Location like isnull(@Location,'')+'%' and c.Warranty!=0 and a.ExpireDate is not null
		End
	----根据物料汇总	
	Else
	--If @IsSUmByItem='true'
		Begin
			select * into #TempResult_Temp from #TempResult
			Insert into #TempResult
				select '' as  HuId,a.Item ,'' RefItemCode,a.ItemDesc ,'' LotNo,''Location,0 UC,0 Uom,0,
					sum(case when a.ExpireDate <@CurrentDate then 1 else 0 end *a.Qty) Qty0,
					sum(case when a.ExpireDate >@CurrentDate and DATEADD(day,-c.WarnLeadTime,a.ExpireDate)>@CurrentDate then 1 else 0 end *a.Qty) Qty1,
					sum(case when (DATEADD(day,-c.WarnLeadTime,a.ExpireDate)<=@CurrentDate and @CurrentDate<a.ExpireDate) then 1 else 0 end *a.Qty) Qty2,
					0 RemindExpireDate,0 ExpireDate,
					ROW_NUMBER()over(order by a.item) 
					As RowID from INV_Hu a with(nolock),VIEW_LocationLotDet b with(nolock)  ,MD_Item c
					where a.HuId =b.HuId and a.Item=c.Code and a.HuId is not null and
					a.Item like isnull(@Item,'')+'%' and b.Location like isnull(@Location,'')+'%' and c.Warranty!=0 and a.ExpireDate is not null
					Group by a.Item , a.ItemDesc 
			Delete #TempResult where Qty0=0 and Qty1=0 and Qty2=0
		End
	UPdate a
		Set a.RowID =b.NONO from #TempResult a,(Select *,ROW_NUMBER()over(order by RowID) NONO from #TempResult)b
			Where a.RowID =b.RowID
	Select COUNT(*) from #TempResult

	Declare @IdStart int
	Declare @IdEnd int
	select @IdStart= @PageSize*(@Page-1)+1,@IdEnd=@PageSize*@Page
	--If @IsExport='true'
	--	Begin
	--		Declare @MaxRows int 
	--		select @MaxRows=Value from SYS_EntityPreference with(nolock) where ID='10018'
	--		Select * ,'' LocTo from #TempResult where RowID between 1 and @MaxRows order by RowID
	--		return
	--	End

	----由于存储结果集转化为对象与USP_Report_AgingSearch公用一个方法，所以这里要统一返回的字段
	Create index IX_Item on #TempResult(item)
	Select a.HuId,a.Item ,a.RefItemCode,a.ItemDesc+case when ISNULL(b.RefCode,'')='' then '' else '['+RefCode+']' end ItemDesc,a.LotNo, a.Location,a.UC,a.Uom,a.Qty, Qty0, Qty1, Qty2,a.RemindExpireDate,a.ExpireDate, RowID,''LocTo,'' as Bin , 0 As IsFreeze,0 As QualityType,CAST(0 as decimal(18,2)) TotalQty,CAST(0 as decimal(18,2)) UnAgingQty,null AgingStartTime,null AgingEndTime,
		CAST(0 as decimal(18,2)) AgedQty,CAST(0 as decimal(18,2)) AgingQty,CAST(0 as decimal(18,2)) FreezedQty,
		CAST(0 as decimal(18,2)) NonFreezeQty,CAST(0 as decimal(18,2)) QulifiedQty,CAST(0 as decimal(18,2)) InspectQty,
		CAST(0 as decimal(18,2)) InQulifiedQty,CAST(0 as decimal(18,2)) NoNeedAgingQty from #TempResult a with(nolock),
			MD_Item b with(nolock) where a.Item=b.Code and  RowID between @IdStart and @IdEnd order by RowID
	
END