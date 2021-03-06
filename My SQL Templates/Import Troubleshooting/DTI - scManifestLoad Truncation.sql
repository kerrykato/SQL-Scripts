
/*
select ', max(len([' + name + '])) as [' + name + ']'
from syscolumns
where id = object_id('scmanifestload')
*/

select 
max(len([R1])) as [R1]
, max(len([MainProductID])) as [MainProductID]
, max(len([ProductID])) as [ProductID]
, max(len([RunType])) as [RunType]
, max(len([RunDate])) as [RunDate]
, max(len([TruckID])) as [TruckID]
, max(len([TruckName])) as [TruckName]
, max(len([TruckDropOrder])) as [TruckDropOrder]
, max(len([RouteID])) as [RouteID]
, max(len([RouteType])) as [RouteType]
, max(len([RouteTypeIndicator])) as [RouteTypeIndicator]
, max(len([DepotID])) as [DepotID]
, max(len([DepotDropOrder])) as [DepotDropOrder]
, max(len([Edition])) as [Edition]
, max(len([DrawTotal])) as [DrawTotal]
, max(len([NumberOfStandardBundles])) as [NumberOfStandardBundles]
, max(len([NumberOfKeyBundles])) as [NumberOfKeyBundles]
, max(len([KeyBundleSize])) as [KeyBundleSize]
, max(len([CarrierName])) as [CarrierName]
, max(len([CarrierPhone])) as [CarrierPhone]
, max(len([InsertMixCombination])) as [InsertMixCombination]
, max(len([DropLocation])) as [DropLocation]
, max(len([DropInstructions])) as [DropInstructions]
, max(len([AdZone])) as [AdZone]
, max(len([PreprintDemographic])) as [PreprintDemographic]
, max(len([InsertExceptionIndicator])) as [InsertExceptionIndicator]
, max(len([BulkIndicator])) as [BulkIndicator]
, max(len([HandTieIndicator])) as [HandTieIndicator]
, max(len([MinimumBundleSize])) as [MinimumBundleSize]
, max(len([MaximumBundleSize])) as [MaximumBundleSize]
, max(len([StandardBundleSize])) as [StandardBundleSize]
, max(len([MapReference])) as [MapReference]
, max(len([MapNumber])) as [MapNumber]
, max(len([MultipackID])) as [MultipackID]
, max(len([WeightOfProduct])) as [WeightOfProduct]
, max(len([TotalDropWeight])) as [TotalDropWeight]
, max(len([StandardBundleWeight])) as [StandardBundleWeight]
, max(len([SingleCopyRate])) as [SingleCopyRate]
, max(len([CarrierId])) as [CarrierId]
, max(len([ChuteNumber])) as [ChuteNumber]
, max(len([DepartureOrder])) as [DepartureOrder]
from scManifestLoad