---@class (exact) Neighbor
---@field bridge_port FBBridgePort? # known port if any
---@field address int32 # neighbor's link layer address
---@field last_seen MapTick # tick last seen transmit from
---@field last_sought MapTick # tick last seen transmit from

---@class (exact) FBBridgePort
---@field send fun(self:FBBridgePort, packet:QueuedPacket)
---@field label fun(self:FBBridgePort):string

---@class bridge
local bridge = {}

---@private
---@param node FBBridgePort
---@param address int32
function bridge.seen(node, address)
  local neighbor = storage.neighbors[address]
  if neighbor then
    neighbor.bridge_port = node
    neighbor.last_seen = game.tick
  else
    neighbor = {
      address = address,
      bridge_port = node,
      last_seen = game.tick,
      last_sought = 0,
    }
    storage.neighbors[address] = neighbor
  end
end

---@param packet QueuedPacket
---@return QueuedPacket
local function copy_packet(packet)
  return {
    proto = packet.proto,
    src_addr = packet.src_addr,
    dest_addr = packet.dest_addr,
    retry_count = packet.retry_count,
    payload = packet.payload,
  }
end

---@private
---@param packet QueuedPacket
---@param from_port? FBBridgePort
function bridge.broadcast(packet, from_port)
  -- no copying for router/peers, they always succeed (as far as this bridge is concerned, anwyay)
  local router = storage.router
  if router and router ~= from_port then
    router:send(packet)
  end
  for _, peer in pairs(storage.peers) do
    if peer ~= from_port then
      peer:send(packet)
    end
  end
  for _, node in pairs(storage.nodes) do
    if node ~= from_port then
      -- shallow-copy the packet for separate retry counts. sharing payload is fine, it's read-only.
      node:send(copy_packet(packet))
    end
  end
end

---@private
---@param neighbor Neighbor?
---@return FBBridgePort?
function bridge.current_port(neighbor)
  if not neighbor then return end
  neighbor.last_sought = game.tick
  if (game.tick - neighbor.last_seen) > 60*60 then
    neighbor.bridge_port = nil
    return
  end
  return neighbor.bridge_port
end

---@public
---@param packet QueuedPacket
---@param from_port FBBridgePort
function bridge.send(packet, from_port)
  bridge.seen(from_port, packet.src_addr)
  if packet.dest_addr ~= 0 then
    local neighbor = storage.neighbors[packet.dest_addr]
    local port = bridge.current_port(neighbor)
    if port then
      -- send it! (unless from_port == bridge_port)
      if from_port ~= port then
        neighbor.bridge_port:send(packet)
      end
    else
      -- broadcast the packet...
      bridge.broadcast(packet, from_port)
      -- ... and start a neighbor record if needed
      if not neighbor then
        neighbor = {
          address = packet.dest_addr,
          last_seen = 0,
          last_sought = game.tick,
        }
        storage.neighbors[neighbor.address] = neighbor
      end
    end
  else
    -- broadcast the packet
    bridge.broadcast(packet, from_port)
  end
end

return bridge