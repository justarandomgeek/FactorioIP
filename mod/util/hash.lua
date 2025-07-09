local band = bit32.band
local sbyte = string.byte

-- djb2 hash, via https://gist.github.com/scheler/26a942d34fb5576a68c111b05ac3fabe 

---hash a string, or continue a previous hash with a new chunk
---@param str string new data to hash
---@param h? uint32 previous hash value
---@return uint32
local function hash(str, h)
  h = h or 5381

  for i = 1, #str do
    h = band(h*33 + sbyte(str, i), 0x7fffffff)
  end
  return h
end

return hash