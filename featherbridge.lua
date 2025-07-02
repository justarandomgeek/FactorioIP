local featherbridge_proto = Proto("featherbridge","FeatherBridge Peering")

local fb_msgtype = {
    [1] = "signals",
}
local msgtype_pfield = ProtoField.uint8("featherbridge.msgtype", "Message Type", base.DEC, fb_msgtype)

-- for msgtype 1 signals:
local fb_fnetproto = {
    [0] = "RAW",
    [1] = "IPv6",
    [2] = "FCP",
    [3] = "Map Request",
    [4] = "Map Transfer",
    [5] = "Map Transfer Extended",
}
local proto_pfield = ProtoField.int32("featherbridge.proto", "Protocol ID", base.DEC, fb_fnetproto)
local src_pfield = ProtoField.int32("featherbridge.src", "Source Address", base.DEC)
local dst_pfield = ProtoField.int32("featherbridge.dst", "Dest Address", base.DEC)

local numqual_pfield = ProtoField.uint8("featherbridge.numqual", "Number of Quality Sections", base.DEC)
local qual_pfield = ProtoField.string("featherbridge.quality", "Quality")
local numsigs_pfield = ProtoField.uint24("featherbridge.numsigs", "Number of Signals", base.DEC)

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
local sigtype_pfield = ProtoField.uint8("featherbridge.sigtype", "Type", base.DEC, fb_sigtype)
local signame_pfield = ProtoField.string("featherbridge.signame", "Name")
local sigvalue_pfield = ProtoField.int32("featherbridge.sigtype", "Value", base.DEC)

featherbridge_proto.fields = {
    msgtype_pfield,
    proto_pfield,
    src_pfield,
    dst_pfield,
    numqual_pfield,
    qual_pfield,
    numsigs_pfield,
    sigtype_pfield,
    signame_pfield,
    sigvalue_pfield,
}

function featherbridge_proto.dissector(buffer,pinfo,tree)
    pinfo.columns.protocol = "FeatherBridge"
    local message = tree:add(featherbridge_proto,buffer())
    message:add(msgtype_pfield, buffer(0,1))
    --TODO: switch on message type? my own dissectortable for it?
    if buffer(0,1):uint() ~= 1 then return end

    pinfo.columns.info = ""

    message:add(proto_pfield, buffer(1,4))

    local srcbuff = buffer(5,4)
    message:add(src_pfield, srcbuff)
    --pinfo.src = srcbuff:ipv4() -- src and dst only take Address objects, ipv4 is the only one the right size...
    local dstbuff = buffer(9,4)
    message:add(dst_pfield, dstbuff)
    --pinfo.dst = dstbuff:ipv4()

    local numqual = buffer(13,1)
    message:add(numqual_pfield, numqual)

    local offset = 14

    --TODO: also collect the signals in a table for a dissector pulling out fnet protocols (as expertinfos?)
    for i = 1, numqual:uint(), 1 do
        local namesize = buffer(offset,1):uint()
        local qual = message:add(qual_pfield, buffer(offset, namesize+1), buffer(offset+1, namesize):string())
        offset = offset+namesize+1
        local numsigbuff = buffer(offset,3)
        offset = offset+3
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
        end
    end
end


DissectorTable.get("udp.port"):add_for_decode_as(featherbridge_proto)