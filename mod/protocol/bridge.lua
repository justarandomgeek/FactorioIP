local protocol = require("protocol.protocol")
local fcp = require("protocol.fcp")

---@class bridge
local bridge = {}

---@param packet QueuedPacket
---@param from_port? FBNode
function bridge.broadcast(packet, from_port)
  for _, node in pairs(storage.nodes) do
    if node ~= from_port then
      -- shallow-copy the packet for separate retry counts. sharing payload is fine, it's read-only.
      node.out_queue[#node.out_queue+1] = {
        dest_addr = packet.dest_addr,
        retry_count = packet.retry_count,
        payload = packet.payload,
      }
    end
  end
end

---@param neighbor Neighbor
function bridge.solicit(neighbor)
  if (game.tick - neighbor.last_seen) < 30*60 or (game.tick - neighbor.last_solicit) < 30 then
    return
  end
  ---@type QueuedPacket
  local sol = { dest_addr = 0, payload = fcp.solicit(neighbor.address) }
  bridge.broadcast(sol)
  neighbor.last_solicit = game.tick
  if (game.tick - neighbor.last_seen) > 60*60 then
    neighbor.bridge_port = nil
  end
end

---@param packet QueuedPacket
---@param from_port? FBNode
function bridge.send(packet, from_port)
  if packet.dest_addr ~= 0 then
    local neighbor = storage.neighbors[packet.dest_addr]
    if neighbor and neighbor.bridge_port then
      -- send it! (unless from_port == bridge_port)
      if from_port ~= neighbor.bridge_port then
        local out_queue = neighbor.bridge_port.out_queue
        out_queue[#out_queue+1] = packet
      end
      -- also broadcast a solicit if stale
      bridge.solicit(neighbor)
    else
      -- broadcast the packet...
      bridge.broadcast(packet, from_port)
      -- ... and a solicit, to know where for next time...
      neighbor = {
        address = packet.dest_addr,
        last_seen = 0,
        last_solicit = 0,
      }
      storage.neighbors[neighbor.address] = neighbor
      bridge.solicit(neighbor)
    end
  else
    -- broadcast the packet
    bridge.broadcast(packet, from_port)
  end
end

---@param node FBNode
---@param net LuaCircuitNetwork
---@param dest_addr? int32
function bridge.forward(node, net, dest_addr)
  local signals = net.signals
  ---@cast signals -?
  ---@type LogisticFilter[]
  local payload = {}
  for _, signal in pairs(signals) do
    payload[#payload+1] = protocol.signal_value(signal.signal, signal.count)
  end
  bridge.send({
    dest_addr = dest_addr or 0,
    retry_count = 2,
    payload = payload,
  }, node)
end

return bridge