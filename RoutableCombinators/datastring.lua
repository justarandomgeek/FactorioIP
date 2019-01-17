--[[
| bits | U+first   | U+last     | bytes | Byte_1   | Byte_2   | Byte_3   | Byte_4   | Byte_5   | Byte_6   |
+------+-----------+------------+-------+----------+----------+----------+----------+----------+----------+
|   7  | U+0000    | U+007F     |   1   | 0xxxxxxx |          |          |          |          |          |
|  11  | U+0080    | U+07FF     |   2   | 110xxxxx | 10xxxxxx |          |          |          |          |
|  16  | U+0800    | U+FFFF     |   3   | 1110xxxx | 10xxxxxx | 10xxxxxx |          |          |          |
|  21  | U+10000   | U+1FFFFF   |   4   | 11110xxx | 10xxxxxx | 10xxxxxx | 10xxxxxx |          |          |
+------+-----------+------------+-------+----------+----------+----------+----------+----------+----------+
| *26  | U+200000  | U+3FFFFFF  |   5   | 111110xx | 10xxxxxx | 10xxxxxx | 10xxxxxx | 10xxxxxx |          |
| *32  | U+4000000 | U+FFFFFFFF |   6   | 111111xx | 10xxxxxx | 10xxxxxx | 10xxxxxx | 10xxxxxx | 10xxxxxx |

VarInt based on UTF-8, extended for full 32bit ints in 6byte form.

--]]

-- reads an int from str starting at index. Returns value,nextindex
function ReadVarInt(str,index)

    local c = string.byte(str, index) or 0
    seq = c < 0x80 and 1 or c < 0xE0 and 2 or c < 0xF0 and 3 or c < 0xF8 and 4 or c < 0xFC and 5 or 6

    if seq == 1 then
        return c,index+1
    else
        val = bit32.band(c, 2^(8-seq) - 1)

        for i=1,seq-1 do
            val = bit32.bor(bit32.lshift(val, 6), bit32.band(string.byte(str, index+i), 0x3F))
        end

        if val > 0x7fffffff then val = val - 0x100000000 end

        return val,index+seq
    end
end

-- convert an int to a string containing the encoded value
function WriteVarInt(val)
    --[[make everythign unsigned values...]]
    if val < 0 then val = val + 0x100000000 end

    local prefix, firstmask, startshift

    if val < 0x80 then
        --[[1 byte]]
        return string.char(val)
    elseif val < 0x0800 then
        --[[2 bytes]]
        prefix = 0xc0
        firstmask = 0x1f
        startshift = 6
    elseif val < 0x10000 then
        --[[3 bytes]]
        prefix = 0xe0
        firstmask = 0x0f
        startshift = 12
    elseif val < 0x200000 then
        --[[4 bytes]]
        prefix = 0xf0
        firstmask = 0x07
        startshift = 18
    elseif val < 0x4000000 then
        --[[5 bytes]]
        prefix = 0xf8
        firstmask = 0x03
        startshift = 24
    else
        --[[6 bytes]]
        prefix = 0xfc
        firstmask = 0x03
        startshift = 30
    end

    local s = {}
    table.insert(s, string.char(bit32.bor(prefix, bit32.band(bit32.rshift(val,startshift),firstmask))))
    for shift=startshift-6,0,-6 do
        table.insert(s, string.char(bit32.bor(0x80, bit32.band(bit32.rshift(val,shift),0x3f))))
    end
    return table.concat(s)


end

--[[
frame = {
    -- IDs broken out seperately to make it easier for JS to do routing
    dstid = int
    srcid = int
    data = {
        [signalid]=value,
        [signalid]=value,
        ...
    }
}

frame = {
    dstid = math.random(0,0xffffffff),
    srcid = math.random(0,0xffffffff),
    data = {
        [1]=math.random(0,0xffffffff),
        [2]=math.random(0,0xffffffff),
        [3]=math.random(0,0xffffffff),
        [5]=math.random(0,0xffffffff),
        [6]=math.random(0,0xffffffff),
        [12]=math.random(0,0xffffffff),
        [11]=math.random(0,0xffffffff),
        [10]=math.random(0,0xffffffff),
        [13]=math.random(0,0xffffffff),
        [14]=math.random(0,0xffffffff),
        [15]=math.random(0,0xffffffff)
    }
}


--]]

-- convert a composed frame to a byte string
function WriteFrame(frame)
    local data = {}
    --[[write dst/source out. Default to -1 (broadcast/unidentified sender), because 0 is illegal value.]]
    table.insert(data,WriteVarInt(frame.dstid or -1))
    table.insert(data,WriteVarInt(frame.srcid or -1))

    local segmentstart = 0
    local segment = {}
    for i,val in pairs(frame.data) do
        if not frame.data[i-1] then
            --[[first item in group]]
            segmentstart = i
            segment = {}
        end

        table.insert(segment,WriteVarInt(val))

        if not frame.data[i+1] then
            --[[last item in group, print a header...]]
            table.insert(data,WriteVarInt(segmentstart))
            table.insert(data,WriteVarInt(#segment))
            table.insert(data,table.concat(segment))

        end
    end
    return table.concat(data)
end

-- convert a byte string to a frame usable for CC configuration
function ReadFrame(strdata)
    --log("ReadFrame ".. serpent.line(strdata))
    local i = 1
    local bytecount = #strdata
    local frame = {}
    local val

    if bytecount == 0 then return nil end

    val,i = ReadVarInt(strdata,i)
    --log("dstid: " .. val)
    if global.signal_to_id_map.virtual['signal-dstid'] then
    table.insert(frame,{count=val,index=#frame+1,signal={name="signal-dstid",type="virtual"}})
    end

    val,i = ReadVarInt(strdata,i)
    --log("srcid: " .. val)
    if global.signal_to_id_map.virtual['signal-srcid'] then
    table.insert(frame,{count=val,index=#frame+1,signal={name="signal-srcid",type="virtual"}})
    end

    while i < bytecount do
        local firstid
        local segmentsize

        firstid,i = ReadVarInt(strdata,i)
        segmentsize,i = ReadVarInt(strdata,i)

        --log("firstid: " .. firstid)
        --log("segmentsize: " .. segmentsize)
        for id=firstid,firstid+segmentsize-1 do
            val,i = ReadVarInt(strdata,i)
            --log("val: " .. val)
            table.insert(frame,{count=val,index=#frame+1,signal=global.id_to_signal_map[id]})
        end
    end

    return frame
end
