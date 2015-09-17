

insert into sys_menu 
select 'Url_CustReport_DOHReport','DOH报表','Menu.CustReport.Info',30,'报表管理-信息-DOH报表','~/CustReport/DOHReport','~/Content/Images/Nav/Default.png',1

insert into ACC_Permission(Code,Desc1,Category,Sequence)
select 'Url_CustReport_DOHReport','报表管理-信息-DOH报表','Menu_CustReport',30



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

	select a.Item,a.planqty as firstmonth,b.planqty as sencondmonth into #temp1 from (select item,sum(planqty) as planqty from MRP_PurchasePlan where planversion = @planversion and windowtime>= @date and windowtime<@first
	group by item) a inner join 
	(select item,sum(planqty) as planqty from MRP_PurchasePlan where planversion = @planversion and windowtime>= @first and windowtime<@sencond
	group by item) b on a.item=b.item


	select a.Item,a.Consumqty,isnull(c.UnitPrice,0) as UnitPrice into #temp2 from (select a.item,-sum(BFQty+Bfrejqty+BFScrapQty) as consumqty from ORD_OrderBackflushDet a where a.createdate>@date
	group by a.item) as a left join bil_pricelistdet c on a.item=c.item  and getdate()>c.startdate and getdate()<c.enddate and not exists(select 1 from bil_pricelistdet e where c.item=e.item and e.startdate-getdate()>c.startdate-getdate())
	left join bil_pricelistmstr d on c.pricelist = d.code and d.type=1 


	select @date as startdate,t1.item,isnull(t2.Consumqty,0) as Consumqty,isnull(t2.UnitPrice,0) as UnitPrice,
		t1.firstmonth,t1.sencondmonth 
	from #temp1 t1 left join #temp2 t2 on t1.item=t2.item
	union all
	select @date as startdate,t2.item,t2.Consumqty,t2.UnitPrice,
		isnull(t1.firstmonth,0) as firstmonth,isnull(t1.sencondmonth,0) as sencondmonth 
	from #temp1 t1 right join #temp2 t2 on t1.item=t2.item where t1.item is null
end
GO


