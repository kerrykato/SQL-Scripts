begin tran

select AttributeName, AttributeValue
from merc_ControlPanel
where AttributeName = 'NewAccountsOnly' 
and AppLayer = 'ForecastEngine'

update merc_ControlPanel
set AttributeValue = case AttributeValue
			when 'true' then 'false'
			else 'true'
			end
where AttributeName = 'NewAccountsOnly' 
and AppLayer = 'ForecastEngine'

select AttributeName, AttributeValue
from merc_ControlPanel
where AttributeName = 'NewAccountsOnly' 
and AppLayer = 'ForecastEngine'

commit tran