

DROP PROCEDURE [dbo].[USP_Report_DOH]
GO

/****** Object:  StoredProcedure [dbo].[USP_Report_DOH]    Script Date: 2015/9/17 14:44:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[USP_Report_DOH]
(
	@StartDate datetime
)
as
begin
		declare @current datetime
	set @current=getdate()

	declare @planversion datetime
	select top 1 @planversion =planversion  from MRP_PurchasePlanMaster a where not exists(select 1 from MRP_PurchasePlanMaster b where b.planversion-@StartDate>a.planversion-@StartDate)
	print @planversion

	declare @date date=@planversion
	select @date=DATEADD(DAY,-(DATEPART(WEEKDAY,@date)-9),@date)

	declare @first date
	set @first=DATEADD(WEEK,4,@date)
	print @first

	declare @sencond date
	set @sencond=DATEADD(WEEK,4,@first)
	print @sencond

	--采购预测
	select a.Item,a.Location,a.planqty as firstmonth,isnull(b.planqty,0) as sencondmonth, 0 as unitprice into #temp1 from (select item,LocationTo as Location,sum(planqty) as planqty from MRP_PurchasePlan where planversion = @planversion and windowtime>= @date and windowtime<@first
	group by item,LocationTo) a left join 
	(select item,LocationTo as Location,sum(planqty) as planqty from MRP_PurchasePlan where planversion = @planversion and windowtime>= @first and windowtime<@sencond
	group by item,LocationTo) b on a.item=b.item and a.location=b.location

	insert into #temp1
	select b.Item,b.Location,isnull(a.planqty,0) as firstmonth,b.planqty as sencondmonth, 0 as unitprice from (select item,LocationTo as Location,sum(planqty) as planqty from MRP_PurchasePlan where planversion = @planversion and windowtime>= @date and windowtime<@first
	group by item,LocationTo) a right join 
	(select item,LocationTo as Location,sum(planqty) as planqty from MRP_PurchasePlan where planversion = @planversion and windowtime>= @first and windowtime<@sencond
	group by item,LocationTo) b on a.item=b.item and a.location=b.location
	where a.item is null

	print '111111'

	update a set a.unitprice=isnull(c.UnitPrice,0) from #temp1 a left join bil_pricelistdet c on a.item=c.item  and @current>c.startdate and @current<c.enddate and not exists(select 1 from bil_pricelistdet e where c.item=e.item and e.startdate-@current>c.startdate-@current)
	left join bil_pricelistmstr d on c.pricelist = d.code and d.type=1 

	print '22222'

	--物料消耗
	select a.Item,a.Location,a.Consumqty,isnull(c.UnitPrice,0) as UnitPrice into #temp2 from (select a.item,a.LocFrom as Location,-sum(BFQty+Bfrejqty+BFScrapQty) as consumqty from ORD_OrderBackflushDet a where a.createdate>dateadd(day,-30,@current)
	group by a.item,a.LocFrom) as a left join bil_pricelistdet c on a.item=c.item  and @current>c.startdate and @current<c.enddate and not exists(select 1 from bil_pricelistdet e where c.item=e.item and e.startdate-@current>c.startdate-@current)
	left join bil_pricelistmstr d on c.pricelist = d.code and d.type=1 

	--销售预测
	select a.Item,a.Location,a.planqty as firstmonth,isnull(b.planqty,0) as sencondmonth, 0 as unitprice into #temp3 from (select Item,Location,Sum(Qty) as planqty from MRP_MrpPlan where PlanDate between getdate() and dateadd(day,28,getdate()) and orderType=3
	group by Item,Location) a left join (select Item,Location,Sum(Qty) as planqty from MRP_MrpPlan where PlanDate between dateadd(day,28,getdate()) and dateadd(day,56,getdate()) and orderType=3
	group by Item,Location) b on a.item=b.item and a.location=b.location

	insert into #temp3
	select b.Item,b.Location,isnull(a.planqty,0) as firstmonth,b.planqty as sencondmonth, 0 as unitprice from (select Item,Location,Sum(Qty) as planqty from MRP_MrpPlan where PlanDate between getdate() and dateadd(day,28,getdate()) and orderType=3
	group by Item,Location) a right join (select Item,Location,Sum(Qty) as planqty from MRP_MrpPlan where PlanDate between dateadd(day,28,getdate()) and dateadd(day,56,getdate()) and orderType=3
	group by Item,Location) b on a.item=b.item and a.location=b.location

	update a set a.unitprice=isnull(c.UnitPrice,0) from #temp3 a left join bil_pricelistdet c on a.item=c.item  and @current>c.startdate and @current<c.enddate and not exists(select 1 from bil_pricelistdet e where c.item=e.item and e.startdate-@current>c.startdate-@current)
	left join bil_pricelistmstr d on c.pricelist = d.code and d.type=2 

	
	select a.startdate,a.item,a.location,b.SAPLocation,a.Consumqty,a.UnitPrice,a.firstmonth,a.sencondmonth from (select cast(@current as date) as startdate,isnull(t1.item,t2.item) as item,isnull(t1.Location,t2.Location) as location,isnull(t2.Consumqty,0) as Consumqty,isnull(t2.UnitPrice,0) as UnitPrice,
		isnull(t1.firstmonth,0) as firstmonth,isnull(t1.sencondmonth,0) as sencondmonth
	from #temp1 t1 full outer join #temp2 t2 on t1.item=t2.item
	union all
	select cast(@current as date) as startdate,isnull(t1.item,t2.item) as item,isnull(t1.Location,t2.Location) as location,isnull(t2.Consumqty,0) as Consumqty,isnull(t2.UnitPrice,0) as UnitPrice,
		isnull(t1.firstmonth,0) as firstmonth,isnull(t1.sencondmonth,0) as sencondmonth
	from #temp3 t1 left join #temp2 t2 on t1.item=t2.item) as a inner join md_location b on a.location=b.code
end
GO


