No_Profiler_Commands = true
local ProfilerLoaded,Profiler = pcall(require,'__profiler__/profiler.lua')
if not ProfilerLoaded then Profiler=nil end

pcall(require,'__coverage__/coverage.lua')

require("util")
require("config")

local deflate = require "zlib-deflate"
require("datastring")
------------------------------------------------------------
--[[Method that handle creation and deletion of entities]]--
------------------------------------------------------------
function OnBuiltEntity(event)
  local entity = event.created_entity
  if entity.name == "entity-ghost" then return end
  AddEntity(entity)
end

function AddAllEntitiesOfNames(names)
  local filters = {}
  for i = 1, #names do
    local name = names[i]
    filters[#filters + 1] = {name = name}
  end
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered(filters)) do
      AddEntity(entity)
    end
  end
end

function AddEntity(entity)
  if entity.name == TX_COMBINATOR_NAME then
    global.txControls[entity.unit_number] = entity.get_or_create_control_behavior()
  elseif entity.name == RX_COMBINATOR_NAME then
    global.rxControls[entity.unit_number] = entity.get_or_create_control_behavior()
    entity.operable=false
  elseif entity.name == ID_COMBINATOR_NAME then
    local control = entity.get_or_create_control_behavior()
    control.parameters = { parameters = {
      {index = 1, count = global.worldID or -1, signal = {type = "virtual", name = "signal-localid"}}
    }}

    entity.operable=false
  end
end

function OnKilledEntity(event)
  local entity = event.entity
  --remove the entities from the tables as they are dead
  if entity.name == TX_COMBINATOR_NAME then
    global.txControls[entity.unit_number] = nil
  elseif entity.name == RX_COMBINATOR_NAME then
    global.rxControls[entity.unit_number] = nil
  end
end

-----------------------------
--[[Thing creation events]]--
-----------------------------
script.on_event(defines.events.on_built_entity, OnBuiltEntity)
script.on_event(defines.events.on_robot_built_entity, OnBuiltEntity)

----------------------------
--[[Thing killing events]]--
----------------------------
script.on_event(defines.events.on_entity_died, OnKilledEntity)
script.on_event(defines.events.on_robot_pre_mined, OnKilledEntity)
script.on_event(defines.events.on_pre_player_mined_item, OnKilledEntity)

------------------------------
--[[Thing resetting events]]--
------------------------------
function Reset()
  -- Maps for signalid <> Signal
  global.id_to_signal_map={}
  global.signal_to_id_map={virtual={},fluid={},item={}}
  for _,v in pairs(game.virtual_signal_prototypes) do
    global.id_to_signal_map[#global.id_to_signal_map+1]={id=#global.id_to_signal_map+1, name=v.name, type="virtual"}
    global.signal_to_id_map.virtual[v.name]=#global.id_to_signal_map
  end
  for _,f in pairs(game.fluid_prototypes) do
    global.id_to_signal_map[#global.id_to_signal_map+1]={id=#global.id_to_signal_map+1, name=f.name, type="fluid"}
    global.signal_to_id_map.fluid[f.name]=#global.id_to_signal_map
  end
  for _,i in pairs(game.item_prototypes) do
    global.id_to_signal_map[#global.id_to_signal_map+1]={id=#global.id_to_signal_map+1, name=i.name, type="item"}
    global.signal_to_id_map.item[i.name]=#global.id_to_signal_map
  end
  global.rxControls = {}
  global.rxBuffer = {}
  global.txControls = {}
  global.txSignals = {}
  global.oldTXSignals = nil

  AddAllEntitiesOfNames(
  {
    RX_COMBINATOR_NAME,
    TX_COMBINATOR_NAME,
    ID_COMBINATOR_NAME,
  })
end

script.on_init(Reset)

script.on_configuration_changed(function(data)
  if data.mod_changes and data.mod_changes["routablecombinators"] then
    Reset()
  end
end)

script.on_event(defines.events.on_tick, function(event)
  -- TX Combinators must run every tick to catch single pulses
  HandleTXCombinators()

  -- RX Combinators are set and then cleared on sequential ticks to create pulses
  UpdateRXCombinators()
end)

---------------------------------
--[[Update combinator methods]]--
---------------------------------
function AddFrameToRXBuffer(frame)
  --game.print("RXb"..game.tick..":"..serpent.block(frame))

  -- if buffer is full, drop frame
  if #global.rxBuffer >= settings.global["routablecombinators-rx-buffer-size"].value then return 0 end

  table.insert(global.rxBuffer,frame)

  return settings.global["routablecombinators-rx-buffer-size"].value - #global.rxBuffer
end

function HandleTXCombinators()
  -- Check all TX Combinators, and if condition satisfied, add frame to transmit buffer

  --[[
  txsignals = {
    dstid = int or nil
    srcid = int or nil
    data = {
      [signalid]=value,
      [signalid]=value,
      ...
    }
  }
  --]]
  local hassignals = false
  local txsignals = {
    srcid=global.worldID,
    data={}
  }
  for i,txControl in pairs(global.txControls) do
    if txControl.valid then
      -- frame = {{count=42,signal={name="signal-grey",type="virtual"}},{...},...}
      local frame = txControl.signals_last_tick
      if frame then
        for _,signal in pairs(frame) do
          local signalName = signal.signal.name
          if signalName == "signal-srcid"  or  signalName == "signal-srctick" then
            -- skip these two, to enforce correct values.
          elseif signalName == "signal-dstid" then
            -- dstid has a special field to go in (this is mostly to make unicast easier on the js side)
            --game.print("TX"..game.tick..":".."dstid"..signal.count)
            txsignals.dstid = (txsignals.dstid or 0) + signal.count
          else
            local sigid = global.signal_to_id_map[signal.signal.type][signalName]
            txsignals.data[sigid] = (txsignals.data[sigid] or 0) + signal.count
            hassignals = true
          end
        end
      end
    end
  end

  if hassignals then

    --Don't send the exact same signals in a row
    -- have to clear tick from old frame and compare before adding to new or it'll always differ
    local sigtick = global.signal_to_id_map["virtual"]["signal-srctick"]
    if global.oldTXSignals and table.compare(global.oldTXSignals, txsignals) then
      global.oldTXSignals = txsignals
      return
    else
      global.oldTXSignals = txsignals



      txsignals.data[sigtick] = game.tick

      --game.print("TX"..game.tick..":"..serpent.block(txsignals))
      local outstr = WriteFrame(txsignals)
      local size = WriteVarInt(#outstr)
      outstr = size .. outstr


      -- If the buffer is full, discard the oldest frame to prevent this table growing too large
      if #global.txSignals >= settings.global["routablecombinators-tx-buffer-size"].value then
        table.remove(global.txSignals,1)
      end
      global.txSignals[#global.txSignals + 1] = outstr

      -- Loopback for testing
      --AddFrameToRXBuffer(outstr)
    end
  end
end

function UpdateRXCombinators()
  -- if the RX buffer is not empty, get a frame from it and output on all RX Combinators
  if #global.rxBuffer > 0 then
    local frame = ReadFrame(table.remove(global.rxBuffer))
    --log("RX:"..serpent.block(frame))

    for i,rxControl in pairs(global.rxControls) do
      if rxControl.valid then
        rxControl.parameters = {parameters = frame }
        rxControl.enabled = true
      end
    end
  else
    -- no frames to send right now, blank all...
    for i,rxControl in pairs(global.rxControls) do
      if rxControl.valid then
      rxControl.parameters = {parameters = {}}
        rxControl.enabled = false
      end
    end
  end
end

---------------------
--[[Remote things]]--
---------------------
commands.add_command("RoutingGetID","",function(cmd)
  if not global.worldID or global.worldID == 0 then
    -- if no ID, pick one at random...
    global.worldID = math.random(1,2147483647)
  end
  if cmd.player_index and cmd.player_index > 0 then
    game.players[cmd.player_index].print(global.worldID)
  elseif rcon then
    rcon.print(global.worldID)
  end
end)

commands.add_command("RoutingSetID","",function(cmd)
  global.worldID = tonumber(cmd.parameter)

  if global.worldID > 0x7fffffff then
    global.worldID = global.worldID - 0x100000000
  end

  AddAllEntitiesOfNames{ID_COMBINATOR_NAME}

end)

commands.add_command("RoutingRX","",function(cmd)
  -- frame in cmd.parameter
  --log("RX: ".. serpent.line(cmd.parameter))
  AddFrameToRXBuffer(cmd.parameter)
end)

commands.add_command("RoutingTXBuff","",function(cmd)
  if cmd.player_index and cmd.player_index > 0 then
    game.players[cmd.player_index].print("TX Buffer has ".. #global.txSignals .. " frames")
  else
    if next(global.txSignals) then
      -- concat them all and print all in one go, one loooong series of non-zero bytes...
    rcon.print(table.concat(global.txSignals))
    global.txSignals = {}
    end
  end
end)

commands.add_command("RoutingGetMap","",function(cmd)
  -- return maps for use by external tools
  -- id_to_signal is sparse int indexes (js will use stringy numbers), signal_to_id is map["type"]["name"] -> id
  data = util.encode((deflate.gzip(game.table_to_json(global.id_to_signal_map))))
  
  if cmd.player_index and cmd.player_index > 0 then
    game.players[cmd.player_index].print("sigmapdata ".. data:len() .. " char")
  else
    rcon.print(data:len() .. ":" .. data)
  end
end)

commands.add_command("RoutingReset","", Reset)
