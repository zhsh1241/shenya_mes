
/****** Object:  StoredProcedure [dbo].[USP_Report_GetInventoryMonitor]    Script Date: 2015/8/28 9:15:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:  <Author,,Name>
-- Create date: <Create Date,,>
-- Description: <Description,,>
--[USP_Report_GetInventoryMonitor] '30023','','',''
-- =============================================
ALTER PROCEDURE [dbo].[USP_Report_GetInventoryMonitor]
(
 @Location varchar(50),
 @Item varchar(50),
 @itemCategory varchar(50),
 @materialsGroup varchar(50),
 @InventoryType varchar(10)
)
AS
--declare 
-- @Location varchar(50),
-- @itemCategory varchar(50),
-- @materialsGroup varchar(50)
--select * from ORD_OrderDet_1
 
 
BEGIN
 SET NOCOUNT ON;
 SELECT @Location=LTRIM(RTRIM(@Location)),@itemCategory=LTRIM(RTRIM(@itemCategory)),@materialsGroup=LTRIM(RTRIM(@materialsGroup))
 ----Filter column "item" by @itemCategory&@materialsGroup to imrove performance.
 select code as item into #item  from md_item with(nolock) where itemCategory like 
	'%'+isnull(@ItemCategory,'')+'%' and MaterialsGroup like '%'+isnull(@MaterialsGroup,'')+'%'
	and Code like isnull(@Item,'')+'%'
 
----当传入的库位参数@Location为Null时，最后的返回记录集的表#WIP&#safestock#stock，会出现一个Item对应多个Loaction ,这样在最后会出现库存和差额将不正确
----这样Join的时候会出现数据混乱，所以在最开始产生记录集表的时候就舍掉栏位@Location
Declare @LocNull varchar(2)='N'
IF isnull(@Location,'')=''
	Begin
		Set @LocNull='Y'
	End
----在途
 select a.Item,case when @LocNull='Y' then '' else a.LocTo end as LocTo,SUM(IpQty) as recqty into #WIP from 
 (
  select a.Item,a.LocTo, sum((a.Qty - a.RecQty)*a.UnitQty) as IpQty  from
  ORD_IpDet_2 a with(nolock)  where  a.IsClose =0 and QualityType <>2 and ABS(Qty)>ABS(RecQty)
  Group by a.Item,a.LocTo
  union all
  select a.Item,a.LocTo,sum((a.Qty - a.RecQty)*a.UnitQty) as IpQty  from
  ORD_IpDet_7 a with(nolock)  where  a.IsClose =0 and QualityType <>2 and ABS(Qty)>ABS(RecQty)
  Group by a.Item ,a.LocTo
  union all
  select a.Item,a.LocTo,sum((a.Qty - a.RecQty)*a.UnitQty) as IpQty  from
  ORD_IpDet_1 a with(nolock)  where  a.IsClose =0 and QualityType <>2 and ABS(Qty)>ABS(RecQty)
  Group by a.Item ,a.LocTo
 )  a where a.item in (select item from #item)  
      and a.LocTo like '%'+isnull(@Location,'')+'%' 
      Group by a.Item,case when @LocNull='Y' then '' else a.LocTo end
----SafeStockQty one item matches only one flowdet data
 select a.item,case when @LocNull='Y' then '' else a.location end as location,a.safestock,a.maxstock into #safestock from
 (select a.item,isnull(a.locto, b.locto) as location,isnull(a.safestock,0) as safestock , 
 isnull(a.maxstock,0) as maxstock,row_number()over(partition by a.item order by a.maxstock desc) as Seq from
 scm_flowdet a with(nolock),scm_flowmstr b with(nolock) where a.flow = b.code and b.IsActive = 1 and isnull(a.locto, b.locto)
 like '%'+isnull(@Location,'')+'%')a where a.Seq=1 and a.item in (select item from #item) 
 
----TotalStockQty
--select top 100 * from VIEW_LocationDet
 select item,case when @LocNull='Y' then '' else location end as location,sum(qty) as qty,SUM(QualifyQty)QualifyQty ,
	sum(RejectQty)RejectQty ,SUM(FreezeQty)FreezeQty,SUM(qty)-SUM(ATPQty) as validQty,sum(CsQty)CsQty  into #stock from VIEW_LocationDet_IncludeZeroQty with(nolock) 
	where item in (select item from #item) 
	and location like '%'+isnull(@Location,'')+'%'group by item,case when @LocNull='Y' then '' else location end
----Recordset
 select a.location as 库位,a.item as 物料,d.desc1+case when Isnull(RefCode,'')='' then '' else '['+RefCode+']' end as 描述,d.uom as 单位,
	cast(a.qty as numeric(12,2))as 总库存,
	cast(a.validQty as numeric(12,2))as 无效库存,
	cast(a.QualifyQty as numeric(12,2))as 合格数,
	cast(a.RejectQty as numeric(12,2))as 不合格数,
	cast(a.FreezeQty as numeric(12,2))as 冻结数,
	cast(a.CsQty as numeric(12,2))as 寄售库存,
	cast(isnull(b.safestock,0) as numeric(12,2)) as 安全库存,
	cast(isnull(b.maxstock,0) as numeric(12,2)) as 最大库存,
	cast(isnull(recqty,0) as numeric(12,2)) as 在途,
	cast(a.qty-isnull(b.safestock,0) + isnull(recqty,0) as numeric(12,2))as 安全差额,
	cast(a.qty-isnull(b.maxstock,0) + isnull(recqty,0) as numeric(12,2))as 最大差额 into #record
	--cast(cast((a.qty-b.maxstock + isnull(recqty,0))/a.qty  as numeric(12,2))*100 as varchar)+'%' as 百分比
	from #stock a left join #safestock b on b.item=a.item left join #WIP c on c.item=a.item 
	left join MD_Item d on d.code=a.item
----@Location =null 时要去掉@Location的列并汇总各个库存的数量
----1.需要按照百分比,最大库存差额排序
----2.最大库存为0的不要显示百分比


If @LocNull='N'
	Begin
	--SP_help'MD_Item'
		select a.Code as 物料,b.Code 物料组,b.Desc1 物料组描述 into #ItemCategory from MD_Item a with(nolock) , MD_ItemCategory b with(nolock) where a.MaterialsGroup =b.Code 
				and b.SubCategory=5 and a.Code in (select 物料 from #record)
		if(@InventoryType ='0')
		begin	
			select 库位,a.物料,描述,ISNULL(b.物料组,'') 物料组,ISNULL(b.物料组描述,'')物料组描述,单位,总库存,无效库存,合格数,不合格数,冻结数,寄售库存,安全库存,最大库存,在途,case when isnull(安全差额,0)>0 then 0 else 安全差额 end as 安全差额,case when isnull(最大差额,0)<0 then 0 else 最大差额 end as 最大差额,
			case when 最大库存=0 then '' else cast(cast(isnull(最大差额,0)/最大库存  as numeric(12,2))*100 as varchar)+'%' end as 百分比,
			case when isnull(安全差额,0)>0 then 0 else 安全差额 end as seq1
			from #record a left join #ItemCategory b on a.物料=b.物料 
			order by seq1,最大差额
		end
		else if(@InventoryType ='1')
		begin
			select 库位,a.物料,描述,ISNULL(b.物料组,'') 物料组,ISNULL(b.物料组描述,'')物料组描述,单位,总库存,无效库存,合格数,不合格数,冻结数,寄售库存,安全库存,最大库存,在途,case when isnull(安全差额,0)>0 then 0 else 安全差额 end as 安全差额,case when isnull(最大差额,0)<0 then 0 else 最大差额 end as 最大差额,
			case when 最大库存=0 then '' else cast(cast(isnull(最大差额,0)/最大库存  as numeric(12,2))*100 as varchar)+'%' end as 百分比,
			case when isnull(安全差额,0)>0 then 0 else 安全差额 end as seq1
			from #record a left join #ItemCategory b on a.物料=b.物料 where 总库存=0 and 安全库存=0 and 最大库存=0 
			order by seq1,最大差额			
		end
		else
		begin
			select 库位,a.物料,描述,ISNULL(b.物料组,'') 物料组,ISNULL(b.物料组描述,'')物料组描述,单位,总库存,无效库存,合格数,不合格数,冻结数,寄售库存,安全库存,最大库存,在途,case when isnull(安全差额,0)>0 then 0 else 安全差额 end as 安全差额,case when isnull(最大差额,0)<0 then 0 else 最大差额 end as 最大差额,
			case when 最大库存=0 then '' else cast(cast(isnull(最大差额,0)/最大库存  as numeric(12,2))*100 as varchar)+'%' end as 百分比,
			case when isnull(安全差额,0)>0 then 0 else 安全差额 end as seq1
			from #record a left join #ItemCategory b on a.物料=b.物料 where 总库存!=0 or 安全库存!=0 or 最大库存!=0 
			order by seq1,最大差额	
		end
	End
Else
	Begin
		select 物料,描述,单位,sum(总库存)as 总库存,sum(无效库存)无效库存,sum(合格数)合格数,sum(不合格数)不合格数,sum(冻结数)冻结数,sum(寄售库存)寄售库存,sum(安全库存) as 安全库存,sum(最大库存) as 最大库存,
			sum(在途)as 在途,sum(isnull(安全差额,0))as 安全差额,sum(isnull(最大差额,0))as 最大差额 into #record1 from #record 
			group by 物料,描述,单位

		--select item ,count(location) as LocQty into #stock1 from #stock group by item
		select a.Code as 物料,b.Code 物料组,b.Desc1 物料组描述 into #ItemCategory1 from MD_Item a with(nolock) , MD_ItemCategory b with(nolock) where a.MaterialsGroup =b.Code 
			and b.SubCategory=5 and a.Code in (select 物料 from #record)
		--select '' as 库位,a.物料,描述,ISNULL(b.物料组,'') 物料组,ISNULL(b.物料组描述,'')物料组描述,单位,总库存 as 总库存,无效库存,合格数,不合格数,冻结数,寄售库存,安全库存 as 安全库存,最大库存 as 最大库存,
		--	在途 as 在途, isnull(安全差额,0) as 安全差额,isnull(最大差额,0)  as 最大差额,
		--	case when 最大库存=0 then '' else cast(cast(isnull(最大差额,0)/最大库存  as numeric(12,2))*100 as varchar)+'%' end as 百分比,
		--	case when isnull(安全差额,0)>0 then 0 else 安全差额 end as seq1
		--	from #record1 a left join #ItemCategory1 b on a.物料=b.物料  
		--	order by seq1,最大差额

		if(@InventoryType ='0')
		begin
			select '' as 库位,a.物料,描述,ISNULL(b.物料组,'') 物料组,ISNULL(b.物料组描述,'')物料组描述,单位,总库存 as 总库存,无效库存,合格数,不合格数,冻结数,寄售库存,安全库存 as 安全库存,最大库存 as 最大库存,
			在途 as 在途, isnull(安全差额,0) as 安全差额,isnull(最大差额,0)  as 最大差额,
			case when 最大库存=0 then '' else cast(cast(isnull(最大差额,0)/最大库存  as numeric(12,2))*100 as varchar)+'%' end as 百分比,
			case when isnull(安全差额,0)>0 then 0 else 安全差额 end as seq1
			from #record1 a left join #ItemCategory1 b on a.物料=b.物料  
			order by seq1,最大差额
		end
		else if(@InventoryType ='1')
		begin
			select '' as 库位,a.物料,描述,ISNULL(b.物料组,'') 物料组,ISNULL(b.物料组描述,'')物料组描述,单位,总库存 as 总库存,无效库存,合格数,不合格数,冻结数,寄售库存,安全库存 as 安全库存,最大库存 as 最大库存,
			在途 as 在途, isnull(安全差额,0) as 安全差额,isnull(最大差额,0)  as 最大差额,
			case when 最大库存=0 then '' else cast(cast(isnull(最大差额,0)/最大库存  as numeric(12,2))*100 as varchar)+'%' end as 百分比,
			case when isnull(安全差额,0)>0 then 0 else 安全差额 end as seq1
			from #record1 a left join #ItemCategory1 b on a.物料=b.物料 where 总库存=0 and 安全库存=0 and 最大库存=0 
			order by seq1,最大差额		
		end
		else
		begin
			select '' as 库位,a.物料,描述,ISNULL(b.物料组,'') 物料组,ISNULL(b.物料组描述,'')物料组描述,单位,总库存 as 总库存,无效库存,合格数,不合格数,冻结数,寄售库存,安全库存 as 安全库存,最大库存 as 最大库存,
			在途 as 在途, isnull(安全差额,0) as 安全差额,isnull(最大差额,0)  as 最大差额,
			case when 最大库存=0 then '' else cast(cast(isnull(最大差额,0)/最大库存  as numeric(12,2))*100 as varchar)+'%' end as 百分比,
			case when isnull(安全差额,0)>0 then 0 else 安全差额 end as seq1
			from #record1 a left join #ItemCategory1 b on a.物料=b.物料 where 总库存!=0 or 安全库存!=0 or 最大库存!=0 
			order by seq1,最大差额		
		end
	End

--select @Location ,'物料',' 描述',' 单位 ',100.0M,200.0M,300.0M,120.0M,-10.0M,30.0M,'10%'
 
END


