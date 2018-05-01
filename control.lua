require("config")
local json = require("json")

function OnBuiltEntity(event)
	local entity = event.created_entity
	if not (entity and entity.valid) then return end
	
	local player = false
	if event.player_index then player = game.players[event.player_index] end
	
	local spawn
	if player and player.valid then
		spawn = game.players[event.player_index].force.get_spawn_position(entity.surface)
	else
		spawn = game.forces["player"].get_spawn_position(entity.surface)
	end
	local x = entity.position.x - spawn.x
	local y = entity.position.y - spawn.y
	
	local name = entity.name
	if name == "entity-ghost" then name = entity.ghost_name end
	
	if ENTITY_TELEPORTATION_RESTRICTION and (name == INPUT_CHEST_NAME or name == OUTPUT_CHEST_NAME or name == INPUT_TANK_NAME or name == OUTPUT_TANK_NAME) then
		if (x < global.config.PlacableArea and x > 0-global.config.PlacableArea and y < global.config.PlacableArea and y > 0-global.config.PlacableArea) then
			--only add entities that are not ghosts
			if entity.type ~= "entity-ghost" then
				AddEntity(entity)
			end
		else
			if player and player.valid then
				-- Tell the player what is happening
				if player then player.print("Attempted placing entity outside allowed area (placed at x "..x.." y "..y.." out of allowed "..global.config.PlacableArea..")") end
				-- kill entity, try to give it back to the player though
				if not player.mine_entity(entity, true) then
					entity.destroy()
				end
			else
				-- it wasn't placed by a player, we can't tell em whats wrong
				entity.destroy()
			end
		end
	else
		--only add entities that are not ghosts
		if entity.type ~= "entity-ghost" then
			AddEntity(entity)
		end
	end
end

function AddAllEntitiesOfName(name)
	for k, surface in pairs(game.surfaces) do
		AddEntities(surface.find_entities_filtered({["name"] = name}))
	end
end

function AddEntities(entities)
	for k, entity in pairs(entities) do
		AddEntity(entity)
	end
end

function AddEntity(entity)
	if entity.name == INPUT_CHEST_NAME then
		--add the chests to a lists if these chests so they can be interated over
		global.inputChests[entity.unit_number] = entity
	elseif entity.name == OUTPUT_CHEST_NAME then
		--add the chests to a lists if these chests so they can be interated over
		global.outputChests[entity.unit_number] = entity
	elseif entity.name == INPUT_TANK_NAME then
		--add the chests to a lists if these chests so they can be interated over
		global.inputTanks[entity.unit_number] = entity
	elseif entity.name == OUTPUT_TANK_NAME then
		--add the chests to a lists if these chests so they can be interated over
		global.outputTanks[entity.unit_number] = entity
		entity.active = false
	elseif entity.name == TX_COMBINATOR_NAME then
		global.txControls[entity.unit_number] = entity.get_or_create_control_behavior()
	elseif entity.name == RX_COMBINATOR_NAME then
		global.rxControls[entity.unit_number] = entity.get_or_create_control_behavior()
		entity.operable=false
	elseif entity.name == INV_COMBINATOR_NAME then
		global.invControls[entity.unit_number] = entity.get_or_create_control_behavior()
		entity.operable=false
	elseif entity.name == INPUT_ELECTRICITY_NAME then
		global.inputElectricity[entity.unit_number] = entity
	elseif entity.name == OUTPUT_ELECTRICITY_NAME then
		global.outputElectricity[entity.unit_number] = entity
	end
end

function OnKilledEntity(event)
	local entity = event.entity
	if entity.type ~= "entity-ghost" then
		--remove the entities from the tables as they are dead
		if entity.name == INPUT_CHEST_NAME then
			global.inputChests[entity.unit_number] = nil
		elseif entity.name == OUTPUT_CHEST_NAME then
			global.outputChests[entity.unit_number] = nil
		elseif entity.name == INPUT_TANK_NAME then
			global.inputTanks[entity.unit_number] = nil
		elseif entity.name == OUTPUT_TANK_NAME then
			global.outputTanks[entity.unit_number] = nil
		elseif entity.name == TX_COMBINATOR_NAME then
			global.txControls[entity.unit_number] = nil
		elseif entity.name == RX_COMBINATOR_NAME then
			global.rxControls[entity.unit_number] = nil
		elseif entity.name == INV_COMBINATOR_NAME then
			global.invControls[entity.unit_number] = nil
		elseif entity.name == INPUT_ELECTRICITY_NAME then
			global.inputElectricity[entity.unit_number] = nil
		elseif entity.name == OUTPUT_ELECTRICITY_NAME then
			global.outputElectricity[entity.unit_number] = nil
		end
	end
end

--[[ Thing Creation Events ]]--
script.on_event(defines.events.on_built_entity, function(event)
	OnBuiltEntity(event)
end)
script.on_event(defines.events.on_robot_built_entity, function(event)
	OnBuiltEntity(event)
end)



--[[ Thing Killing Events ]]--
script.on_event(defines.events.on_entity_died, function(event)
	OnKilledEntity(event)
end)
script.on_event(defines.events.on_robot_pre_mined, function(event)
	OnKilledEntity(event)
end)
script.on_event(defines.events.on_pre_player_mined_item, function(event)
	OnKilledEntity(event)
end)


script.on_init(function()
	Reset()
end)

script.on_configuration_changed(function(data)
	if data.mod_changes and data.mod_changes["clusterio"] then
		Reset()
	end
end)

script.on_event(defines.events.on_tick, function(event)
	-- TX Combinators must run every tick to catch single pulses
	HandleTXCombinators()

	global.ticksSinceMasterPinged = 0
	
	global.ticksSinceMasterPinged = global.ticksSinceMasterPinged + 1
	if global.ticksSinceMasterPinged < 300 then
		local todo = game.tick % UPDATE_RATE
		local timeSinceLastElectricityUpdate = game.tick - global.lastElectricityUpdate
		if todo == 0 then
			HandleInputChests()
		elseif todo == 1 then
			HandleInputTanks()
		elseif todo == 2 then
			HandleOutputChests()
		elseif todo == 3 then
			HandleOutputTanks()
		elseif todo == 4 then
			HandleInputElectricity()
		--importing electricity should be limited because it requests so
		--much at once. If it wasn't limited then the electricity could
		--make small burst of requests which requests >10x more than it needs
		--which could temporarily starve other networks.
		--Updating every 4 seconds give two chances to give electricity in
		--the 10 second period.
		elseif todo == 5 and timeSinceLastElectricityUpdate >= 60 * 4 then -- only update ever 4 seconds
			HandleOutputElectricity()
			global.lastElectricityUpdate = game.tick
		elseif todo == 6 then
			ExportInputList()
		elseif todo == 7 then
			ExportOutputList()
		elseif todo == 8 then
			ExportFluidFlows()
		elseif todo == 9 then
			ExportItemFlows()
		end
	end

	-- RX Combinators are set and then cleared on sequential ticks to create pulses
	UpdateRXCombinators()
end)

function ExportItemFlows()
	local flowreport = {type="item",flows={}}

	for _,force in pairs(game.forces) do
		flowreport.flows[force.name] = {
			input_counts = force.item_production_statistics.input_counts,
			output_counts = force.item_production_statistics.output_counts,
		}
	end

	game.write_file(FLOWS_FILE, json:encode(flowreport).."\n", true, global.write_file_player or 0)
end

function ExportFluidFlows()
	local flowreport = {type="fluid",flows={}}

	for _,force in pairs(game.forces) do
		flowreport.flows[force.name] = {
			input_counts = force.fluid_production_statistics.input_counts,
			output_counts = force.fluid_production_statistics.output_counts,
		}
	end

	game.write_file(FLOWS_FILE, json:encode(flowreport).."\n", true, global.write_file_player or 0)
end

function Reset()
	global.ticksSinceMasterPinged = 601

	if global.config==nil then global.config={BWitems={},item_is_whitelist=false,BWfluids={},fluid_is_whitelist=false,PlacableArea=400} end
	if global.invdata==nil then global.invdata={} end
	
	global.outputList = {}
	global.inputList = {}
	global.itemStorage = {}

	global.inputChests = {}
	global.outputChests = {}

	global.inputTanks = {}
	global.outputTanks = {}

	global.rxControls = {}
	global.txControls = {}
	global.invControls = {}
	
	global.inputElectricity = {}
	global.outputElectricity = {}
	global.lastElectricityUpdate = 0
	global.maxElectricity = 100000000000000 / ELECTRICITY_RATIO --100TJ

	AddAllEntitiesOfName(INPUT_CHEST_NAME)
	AddAllEntitiesOfName(OUTPUT_CHEST_NAME)

	AddAllEntitiesOfName(INPUT_TANK_NAME)
	AddAllEntitiesOfName(OUTPUT_TANK_NAME)

	AddAllEntitiesOfName(RX_COMBINATOR_NAME)
	AddAllEntitiesOfName(TX_COMBINATOR_NAME)
	AddAllEntitiesOfName(INV_COMBINATOR_NAME)
	
	AddAllEntitiesOfName(INPUT_ELECTRICITY_NAME)
	AddAllEntitiesOfName(OUTPUT_ELECTRICITY_NAME)
end

function HandleInputChests()
	for k, v in pairs(global.inputChests) do
		if v.valid then
			--get the content of the chest
			local items = v.get_inventory(defines.inventory.chest).get_contents()
			local inventory=v.get_inventory(defines.inventory.chest)
			--write everything to the file
			for itemName, itemCount in pairs(items) do
				if isItemLegal(itemName) then
					AddItemToInputList(itemName, itemCount)
					inventory.remove({name=itemName,count=itemCount})
				end
			end
		end
	end
end

function HandleInputTanks()
	for k, v in pairs(global.inputTanks) do
		if v.valid then
			--get the content of the chest
			local fluid = v.fluidbox[1]
			if fluid ~= nil and math.floor(fluid.amount) > 0 then
				if isFluidLegal(fluid.name) then
					AddItemToInputList(fluid.name, math.floor(fluid.amount))
					fluid.amount = fluid.amount - math.floor(fluid.amount)
				end
			end
			v.fluidbox[1] = fluid
		end
	end
end

function HandleInputElectricity()
	if global.invdata and global.invdata[ELECTRICITY_ITEM_NAME] and global.invdata[ELECTRICITY_ITEM_NAME] < global.maxElectricity then
		for k, entity in pairs(global.inputElectricity) do
			if entity.valid then
				local availableEnergy = math.floor(entity.energy / ELECTRICITY_RATIO)
				if availableEnergy > 0 then
					AddItemToInputList(ELECTRICITY_ITEM_NAME, availableEnergy)
					entity.energy = entity.energy - (availableEnergy * ELECTRICITY_RATIO)
				end
			end
		end
	end
end

function HandleOutputChests()
	local simpleItemStack = {}
	for k, v in pairs(global.outputChests) do
		if v.valid and not v.to_be_deconstructed(v.force) then
			--get the inventory here once for faster execution
			local chestInventory = v.get_inventory(defines.inventory.chest)
			for i = 1, 12 do
				--the item the chest wants
				local requestItem = v.get_request_slot(i)
				if requestItem ~= nil then
					if isItemLegal(requestItem.name) then
						local itemsInChest = chestInventory.get_item_count(requestItem.name)
						--if there isn't enough items in the chest
						if itemsInChest < requestItem.count then
							local additionalItemRequiredCount = requestItem.count - itemsInChest
							local itemCountAllowedToInsert = RequestItemsFromStorage(requestItem.name, additionalItemRequiredCount)
							if itemCountAllowedToInsert > 0 then
								simpleItemStack.name = requestItem.name
								simpleItemStack.count = itemCountAllowedToInsert
								--insert the missing items
								local insertedItemsCount = chestInventory.insert(simpleItemStack)
								local itemsNotInsertedCount = itemCountAllowedToInsert - insertedItemsCount

								if itemsNotInsertedCount > 0 then
									GiveItemsToStorage(requestItem.name, itemsNotInsertedCount)
								end
							else
								local missingItems = additionalItemRequiredCount - itemCountAllowedToInsert
								AddItemToOutputList(requestItem.name, missingItems)
							end
						end
					end
				end
			end
		end
	end
end

function HandleOutputTanks()
	 for k,v in pairs(global.outputTanks) do
		--.recipe.products[1].name
		if v.get_recipe() ~= nil then
			local fluidName = v.get_recipe().products[1].name

			--either get the fluid or reset it to the requested fluid
			local fluid = v.fluidbox[1] or {name = fluidName, amount = 0}
			if fluid.name ~= fluidName then
				fluid = {name = fluidName, amount = 0}
			end

			--if any fluid is missing then request the fluid
			--from store and give either what it's missing or
			--the rest of the liquid in the system
			local missingFluid = math.max(math.ceil(MAX_FLUID_AMOUNT - fluid.amount), 0)
			if missingFluid > 0 and isFluidLegal(fluidName)then
				local fluidToInsert = RequestItemsFromStorage(fluidName, missingFluid)
				if fluidToInsert > 0 then
					fluid.amount = fluid.amount + fluidToInsert
					if fluid.name == "steam" then
						fluid.temperature = 165
					end
				else
					local fluidToRequestAmount = missingFluid - fluidToInsert
					AddItemToOutputList(fluid.name, fluidToRequestAmount)
				end
			end

		v.fluidbox[1] = fluid
		end
	end
end

function HandleOutputElectricity()
	for k, entity in pairs(global.outputElectricity) do
		if entity.valid then
			local missingElectricity = math.floor(entity.electric_buffer_size - entity.energy)
			if missingElectricity > 0 then
				local receivedElectricity = RequestItemsFromStorage(ELECTRICITY_ITEM_NAME, missingElectricity)
				if receivedElectricity > 0 then
					entity.energy = entity.energy + (receivedElectricity * ELECTRICITY_RATIO)
				else
					AddItemToOutputList(ELECTRICITY_ITEM_NAME, missingElectricity / ELECTRICITY_RATIO)
				end
			end
		end
	end
end


function AddItemToInputList(itemName, itemCount)
	global.inputList[itemName] = (global.inputList[itemName] or 0) + itemCount
end

function AddItemToOutputList(itemName, itemCount)
	global.outputList[itemName] = (global.outputList[itemName] or 0) + itemCount
end



function ExportInputList()
	local exportStrings = {}
	for k,v in pairs(global.inputList) do
		exportStrings[#exportStrings + 1] = k.." "..v.."\n"
	end
	global.inputList = {}
	if #exportStrings > 0 then

		--only write to file once as i/o is slow
		--it's much faster to concatenate all the lines with table.concat
		--instead of doing it with the .. operator
		game.write_file(OUTPUT_FILE, table.concat(exportStrings), true, global.write_file_player or 0)
	end
end

function ExportOutputList()
	local exportStrings = {}
	for k,v in pairs(global.outputList) do
		exportStrings[#exportStrings + 1] = k.." "..v.."\n"
	end
	global.outputList = {}
	if #exportStrings > 0 then

		--only write to file once as i/o is slow
		--it's much faster to concatenate all the lines with table.concat
		--instead of doing it with the .. operator
		game.write_file(ORDER_FILE, table.concat(exportStrings), true, global.write_file_player or 0)
	end
end


function RequestItemsFromStorage(itemName, itemCount)
	--if result is nil then there is no items in storage
	--which means that no items can be given
	if global.itemStorage[itemName] == nil then
		return 0
	end
	--if the number of items in storage is lower than the number of items
	--requested then take the number of items there are left otherwise take the requested amount
	local itemsTakenFromStorage = math.min(global.itemStorage[itemName], itemCount)
	global.itemStorage[itemName] = global.itemStorage[itemName] - itemsTakenFromStorage

	return itemsTakenFromStorage
end

function GiveItemsToStorage(itemName, itemCount)
	--if this is called for the first time for an item then the result
	--is nil. if that's the case then set the result to 0 so it can
	--be used in arithmetic operations
	global.itemStorage[itemName] = global.itemStorage[itemName] or 0
	global.itemStorage[itemName] = global.itemStorage[itemName] + itemCount
end



function AddFrameToRXBuffer(frame)
	-- Add a frame to the buffer. return remaining space in buffer
	local validsignals = {
		["virtual"] = game.virtual_signal_prototypes,
		["fluid"]	 = game.fluid_prototypes,
		["item"]		= game.item_prototypes
	}

	global.rxBuffer = global.rxBuffer or {}

	-- if buffer is full, drop frame
	if #global.rxBuffer >= MAX_RX_BUFFER_SIZE then return 0 end

	-- frame = {{count=42,name="signal-grey",type="virtual"},{...},...}
	local signals = {}
	local index = 1

	for _,signal in pairs(frame) do
		if validsignals[signal.type] and validsignals[signal.type][signal.name] then
			signals[index] =
				{
					index=index,
					count=signal.count,
					signal={ name=signal.name, type=signal.type }
				}
			index = index + 1
			--TODO: break if too many?
			--TODO: error token on mismatched signals? maybe mismatch1-n signals?
		end
	end

	if index > 1 then table.insert(global.rxBuffer,signals) end

	return MAX_RX_BUFFER_SIZE - #global.rxBuffer
end

function HandleTXCombinators()
	-- Check all TX Combinators, and if condition satisfied, add frame to transmit buffer

	-- frame = {{count=42,name="signal-grey",type="virtual"},{...},...}
	local signals = {["item"]={},["virtual"]={},["fluid"]={}}
	for i,txControl in pairs(global.txControls) do
		if txControl.valid then
			local frame = txControl.signals_last_tick
			if frame then
				for _,signal in pairs(frame) do
					signals[signal.signal.type][signal.signal.name]=
						(signals[signal.signal.type][signal.signal.name] or 0) + signal.count
				end
			end
		end
	end

	local frame = {}
	for type,arr in pairs(signals) do
		for name,count in pairs(arr) do
			table.insert(frame,{count=count,name=name,type=type})
		end
	end

	if #frame > 0 then
		if global.worldID then
			table.insert(frame,1,{count=global.worldID,name="signal-srcid",type="virtual"})
		end
		table.insert(frame,{count=game.tick,name="signal-srctick",type="virtual"})
		game.write_file(TX_BUFFER_FILE, json:encode(frame).."\n", true, global.write_file_player or 0)

		-- Loopback for testing
		--AddFrameToRXBuffer(frame)

	end
end

function UpdateRXCombinators()
	-- if the RX buffer is not empty, get a frame from it and output on all RX Combinators
	if global.rxBuffer and #global.rxBuffer > 0 then
		local frame = table.remove(global.rxBuffer)
		for i,rxControl in pairs(global.rxControls) do
			if rxControl.valid then
				rxControl.parameters={parameters=frame}
				rxControl.enabled=true
			end
		end
  else
    -- no frames to send right now, blank all...
    for i,rxControl in pairs(global.rxControls) do
  		if rxControl.valid then
  			rxControl.enabled=false
  		end
  	end
	end
end

function UpdateInvCombinators()
	-- Update all inventory Combinators
	-- Prepare a frame from the last inventory report, plus any virtuals
	local invframe = {}
	if global.worldID then
		table.insert(invframe,{count=global.worldID,index=#invframe+1,signal={name="signal-localid",type="virtual"}})
	end

	local items = game.item_prototypes
	local fluids = game.fluid_prototypes
	local virtuals = game.virtual_signal_prototypes
	if global.invdata then
		for name,count in pairs(global.invdata) do
			if virtuals[name] then
				invframe[#invframe+1] = {count=count,index=#invframe+1,signal={name=name,type="virtual"}}
			elseif fluids[name] then
				invframe[#invframe+1] = {count=count,index=#invframe+1,signal={name=name,type="fluid"}}
			elseif items[name] then
				invframe[#invframe+1] = {count=count,index=#invframe+1,signal={name=name,type="item"}}
			end
		end
	end

	for i,invControl in pairs(global.invControls) do
		if invControl.valid then
			invControl.parameters={parameters=invframe}
			invControl.enabled=true
		end
	end

end

--[[ Remote Thing ]]--
remote.add_interface("clusterio",
{
	runcode=function(codeToRun) loadstring(codeToRun)() end,
	import = function(itemName, itemCount)
		GiveItemsToStorage(itemName, itemCount)
	end,
	importMany = function(jsonString)
		local items = json:decode(jsonString)
		for k, item in pairs(items) do
			for itemName, itemCount in pairs(item) do
				GiveItemsToStorage(itemName, itemCount)
			end
		end
	end,
	printStorage = function()
		local items = ""
		for itemName, itemCount in pairs(global.itemStorage) do
			items = items.."\n"..itemName..": "..tostring(itemCount)
		end
		game.print(items)
	end,
	reset = Reset,
	receiveFrame = function(jsonframe)
		local frame = json:decode(jsonframe)
		-- frame = {tick=123456,frame={{count=42,name="signal-grey",type="virtual"},{...},...}}
		return AddFrameToRXBuffer(frame)
	end,
	receiveMany = function(jsonframes)
		local frames = json:decode(jsonframes)
		local buffer
		for _,frame in pairs(frames) do
			buffer = AddFrameToRXBuffer(frame)
			if buffer==0 then return 0 end
		end
		return buffer
	end,
	setFilePlayer = function(i)
		global.write_file_player = i
	end,
	receiveInventory = function(jsoninvdata)
		global.ticksSinceMasterPinged = 0
		local invdata = json:decode(jsoninvdata)
		for name,count in pairs(invdata) do
			global.invdata[name]=count	
		end
		-- invdata = {["iron-plates"]=1234,["copper-plates"]=5678,...}
		UpdateInvCombinators()
	end,
	setWorldID = function(newid)
		global.worldID = newid
		UpdateInvCombinators()
	end
})




function isFluidLegal(name)
	for _,itemName in pairs(global.config.BWfluids) do
		if itemName==name then
			return global.config.fluid_is_whitelist
		end
	end
	return not global.config.fluid_is_whitelist
end
function isItemLegal(name)
	for _,itemName in pairs(global.config.BWitems) do
		if itemName==name then
			return global.config.item_is_whitelist
		end
	end
	return not global.config.item_is_whitelist
end
function createElemGui_INTERNAL(pane,guiName,elem_type,loadingList)
	local gui = pane.add{ type = "table", name = guiName, column_count = 5 }
	for _,item in pairs(loadingList) do
		gui.add{type="choose-elem-button",elem_type=elem_type,item=item,fluid=item}
	end
	gui.add{type="choose-elem-button",elem_type=elem_type}
end


function toggleBWItemListGui(parent)
	if parent["clusterio-black-white-item-list-config"] then
        parent["clusterio-black-white-item-list-config"].destroy()
        return
    end
	local pane=parent.add{type="frame", name="clusterio-black-white-item-list-config", direction="vertical"}
	pane.add{type="label",caption="Item"}
	pane.add{type="checkbox", name="clusterio-is-item-whitelist", caption="whitelist",state=global.config.item_is_whitelist}
	createElemGui_INTERNAL(pane,"item-black-white-list","item",global.config.BWitems)
end
function toggleBWFluidListGui(parent)
	if parent["clusterio-black-white-fluid-list-config"] then
        parent["clusterio-black-white-fluid-list-config"].destroy()
        return
    end
	local pane=parent.add{type="frame", name="clusterio-black-white-fluid-list-config", direction="vertical"}
	pane.add{type="label",caption="Fluid"}
	pane.add{type="checkbox", name="clusterio-is-fluid-whitelist", caption="whitelist",state=global.config.fluid_is_whitelist}
	createElemGui_INTERNAL(pane,"fluid-black-white-list","fluid",global.config.BWfluids)
end
function processElemGui(event,toUpdateConfigName)--VERY WIP
	parent=event.element.parent
	if event.element.elem_value==nil then event.element.destroy()
	else parent.add{type="choose-elem-button",elem_type=parent.children[1].elem_type} end
	global.config[toUpdateConfigName]={}
	for _,guiElement in pairs(parent.children) do
		if guiElement.elem_value~=nil then
			table.insert(global.config[toUpdateConfigName],guiElement.elem_value)
		end
	end
end

script.on_event(defines.events.on_gui_value_changed,function(event) 
	if event.element.name=="clusterio-Placing-Bounding-Box" then 
		global.config.PlacableArea=event.element.slider_value 
		event.element.parent["clusterio-Placing-Bounding-Box-Label"].caption="Chest/fluid bounding box: "..global.config.PlacableArea
	end 
end)


function toggleMainConfigGui(parent)
	if parent["clusterio-main-config-gui"] then
        parent["clusterio-main-config-gui"].destroy()
        return
    end
	local pane = parent.add{type="frame", name="clusterio-main-config-gui", direction="vertical"}
	pane.add{type="button", name="clusterio-Item-WB-list", caption="Item White/Black list"}
    pane.add{type="button", name="clusterio-Fluid-WB-list", caption="Fluid White/Black list"}
	pane.add{type="label", caption="Chest/fluid bounding box: "..global.config.PlacableArea,name="clusterio-Placing-Bounding-Box-Label"}
	pane.add{type="slider", name="clusterio-Placing-Bounding-Box",minimum_value=0,maximum_value=800,value=global.config.PlacableArea}
	
	--Electricity panel
	local electricityPane = pane.add{type="frame", name="clusterio-main-config-gui", direction="horizontal"}
	electricityPane.add{type="label", name="clusterio-electricity-label", caption="Max electricity"}
	electricityPane.add{type="textfield", name="clusterio-electricity-field", text = global.maxElectricity}
	
end
function processMainConfigGui(event)
	if event.element.name=="clusterio-Item-WB-list" then
		toggleBWItemListGui(game.players[event.player_index].gui.top)
	end
	if event.element.name=="clusterio-Fluid-WB-list" then
		toggleBWFluidListGui(game.players[event.player_index].gui.top)
	end
end
script.on_event(defines.events.on_gui_checked_state_changed, function(event) 
	if not (event.element.parent) then return end
	if event.element.name=="clusterio-is-fluid-whitelist" then 
		global.config.fluid_is_whitelist=event.element.state 
		return
	end
	if event.element.name=="clusterio-is-item-whitelist" then 
		global.config.item_is_whitelist=event.element.state 
		return
	end
end)
	
script.on_event(defines.events.on_gui_click, function(event)
	if not (event.element and event.element.valid) then return end
	if not (event.element.parent) then return end
	local player = game.players[event.player_index]
	if event.element.parent.name=="clusterio-main-config-gui" then processMainConfigGui(event) return end
	if event.element.name=="clusterio-main-config-gui-toggle-button" then toggleMainConfigGui(game.players[event.player_index].gui.top) return end
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
	if not (event.element and event.element.valid) then return end
	if not (event.element.parent) then return end
	
	if event.element.parent.name=="item-black-white-list" then
		processElemGui(event,"BWitems")
		return
	end
	if event.element.parent.name=="fluid-black-white-list" then
		processElemGui(event,"BWfluids")
		return
	end
	if event.element.name == "clusterio-electricity-field" then
		game.print(event.element.text)
		local newMax = tonumber(event.element.text)
		if newMax and newMax >= 0 then
			global.maxElectricity = newMax
		end
	end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
	if not (event.element and event.element.valid) then return end
	
	if event.element.name == "clusterio-electricity-field" then
		game.print(event.element.text)
		local newMax = tonumber(event.element.text)
		if newMax and newMax >= 0 then
			global.maxElectricity = newMax
		end
	end
end)

function makeConfigButton(parent)
	if not parent["clusterio-main-config-gui-button"] then
		local pane = parent.add{type="frame", name="clusterio-main-config-gui-button", direction="vertical"}
		pane.add{type="button", name="clusterio-main-config-gui-toggle-button", caption="config"}
    end
end



script.on_event(defines.events.on_player_joined_game,function(event) 
	if game.players[event.player_index].admin then  
		makeConfigButton(game.players[event.player_index].gui.top)
	end
end)
--script.on_event(defines.events.on_player_died,function(event) 
--	local msg="!shout "..game.players[event.player_index].name.." has been killed"
--	if event.cause~=nil then if event.cause.name~="locomotive" then return end msg=msg.." by "..event.cause.name else msg=msg.."." end
--	game.print( msg)
--end)--game.write_file("alerts.txt","player_died, "..game.players[event.player_index].name.." has killed by "..(event.cause or {name="unknown"}).name,true) end)--
