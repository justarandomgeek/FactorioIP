---@type Proto
local featherbridge_proto = Proto("featherbridge","FeatherBridge Peering")

local fb_msgtype = {
    [1] = "Raw Signals",
    [2] = "Packed Messages",
    [3] = "Peer Info",
}
local msgtype_pfield = ProtoField.uint8("featherbridge.msgtype", "Message Type", base.DEC, fb_msgtype)

local fb_fnetproto = {
    [0] = "RAW",
    [1] = "IPv6",
    [2] = "FCP",
    [3] = "Map Request",
    [4] = "Map Transfer",
    [5] = "Map Transfer Extended",
}

local fb_fnetprotoshort = {
    [0] = "RAW",
    [1] = "IPv6",
    [2] = "FCP",
    [3] = "MapReq",
    [4] = "MapTrans",
    [5] = "MapTransEx",
}
local proto_pfield = ProtoField.int32("featherbridge.fnet_proto", "Protocol ID", base.DEC, fb_fnetproto)
local src_pfield = ProtoField.uint32("featherbridge.src", "Source Address", base.HEX)
local dst_pfield = ProtoField.uint32("featherbridge.dst", "Dest Address", base.HEX)

featherbridge_proto.fields = {
    msgtype_pfield,
    proto_pfield,
    src_pfield,
    dst_pfield,
}

local msgtype_dt = DissectorTable.new("featherbridge.msgtype", "FeatherBridge Message Type", ftypes.UINT8)

function featherbridge_proto.dissector(buffer,pinfo,tree)
    pinfo.columns.protocol = "FeatherBridge"
    local message = tree:add(featherbridge_proto,buffer())
    message:add(msgtype_pfield, buffer(0,1))
    msgtype_dt:try(buffer(0,1):uint(), buffer(1):tvb(), pinfo, message)
end


---@type Proto
local raw_proto = Proto("featherbridge.raw","FeatherBridge Raw Signals")

local numqual_pfield = ProtoField.uint8("featherbridge.raw.numqual", "Number of Quality Sections", base.DEC)
local qual_pfield = ProtoField.string("featherbridge.raw.quality", "Quality")
local numsigs_pfield = ProtoField.uint16("featherbridge.raw.numsigs", "Number of Signals", base.DEC)

local fb_sigtype = {
    [0]="item",
    [1]="fluid",
    [2]="virtual",
    [3]="recipe",
    [4]="entity",
    [5]="space-location",
    [6]="quality",
    [7]="asteroid-chunk",
}
local sigtype_pfield = ProtoField.uint8("featherbridge.raw.sigtype", "Type", base.DEC, fb_sigtype)
local signame_pfield = ProtoField.string("featherbridge.raw.signame", "Name")
local sigvalue_pfield = ProtoField.int32("featherbridge.raw.sigtype", "Value", base.DEC)

raw_proto.fields = {
    numqual_pfield,
    qual_pfield,
    numsigs_pfield,
    sigtype_pfield,
    signame_pfield,
    sigvalue_pfield,
}

local function fnet_address(buffer)
    return Address.ipv6(
        "fe80::"..
        buffer:range(0,2):bytes():tohex()..":"..
        buffer:range(2,2):bytes():tohex())
end

function raw_proto.dissector(buffer,pinfo,tree)
    local message = tree:add(raw_proto,buffer())

    local protoid = buffer(0,4)
    local src = buffer(4,4)
    local dst = buffer(8,4)
    local numqual = buffer(12,1)
    message:add(proto_pfield, protoid)
    message:add(src_pfield, src)
    message:add(dst_pfield, dst)
    message:add(numqual_pfield, numqual)

    -- these have to be wrapped in fake Address objects for the column to take it, 
    -- so pretend they're link-local v6...
    -- v4 or ether woudl be a better "fit" but they display with useless decodes
    pinfo.src = fnet_address(src)
    pinfo.dst = fnet_address(dst)

    local nsig = 0
    local offset = 13

    --TODO: record last seen map transfer?
    --TODO: collect the data from IP-mode in a ByteArray and dissect that?
    for i = 1, numqual:uint(), 1 do
        local namesize = buffer(offset,1):uint()
        local qual = message:add(qual_pfield, buffer(offset, namesize+1), buffer(offset+1, namesize):string())
        offset = offset+namesize+1
        local numsigbuff = buffer(offset,2)
        offset = offset+2
        qual:add(numsigs_pfield, numsigbuff)
        for j = 1, numsigbuff:uint(), 1 do
            local typebuff = buffer(offset,1)
            local signamesize = buffer(offset+1,1):uint()
            local signame = buffer(offset+2,signamesize):string()
            local sigvalbuff = buffer(offset+signamesize+2,4)

            local sig = qual:add(buffer(offset, signamesize+6), string.format("%s/%s: %i", fb_sigtype[typebuff:uint()], signame, sigvalbuff:int()))
            sig:add(sigtype_pfield, typebuff)
            sig:add(signame_pfield, buffer(offset+1,signamesize+1), signame)
            sig:add(sigvalue_pfield, sigvalbuff)

            offset = offset+signamesize+6
            nsig = nsig + 1
        end
    end

    pinfo.columns.info = string.format("%i → %i %s NQual=%i NSig=%i", src:int(), dst:int(), fb_fnetprotoshort[protoid:int()] or "?", numqual:uint(), nsig)
end

msgtype_dt:add(1, raw_proto)


DissectorTable.get("udp.port"):add_for_decode_as(featherbridge_proto)