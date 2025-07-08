local data_dis = Dissector.get("data")

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
    local dis = msgtype_dt:get_dissector(buffer(0,1):uint()) or data_dis
    dis:call(buffer(1):tvb(), pinfo, message)
end

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

---@param buffer TvbRange
local function fnet_address(buffer)
    return Address.ipv6(
        "fe80::"..
        buffer(0,2):bytes():tohex()..":"..
        buffer(2,2):bytes():tohex())
end

---@param buffer TvbRange
---@param pinfo Pinfo
---@param tree TreeItem
---@return {protoid:integer, src:integer, dst:integer}
local function fnet_header(buffer, pinfo, tree)
    local protoid = buffer(0,4)
    local src = buffer(4,4)
    local dst = buffer(8,4)
    tree:add(proto_pfield, protoid)
    tree:add(src_pfield, src)
    tree:add(dst_pfield, dst)
    
    -- these have to be wrapped in fake Address objects for the column to take it, 
    -- so pretend they're link-local v6...
    -- v4 or ether woudl be a better "fit" but they display with useless decodes
    pinfo.src = fnet_address(src)
    pinfo.dst = fnet_address(dst)

    pinfo.columns.info = fb_fnetprotoshort[protoid:int()] or "UNKP"
    return {protoid=protoid:int(), src=src:int(), dst=dst:int()}
end

function raw_proto.dissector(buffer,pinfo,tree)
    fnet_header(buffer(0,12), pinfo, tree)
    local numqual = buffer(12,1)
    tree:add(numqual_pfield, numqual)

    local nsig = 0
    local offset = 13

    --TODO: record last seen map transfer?
    --TODO: collect the data from IP-mode in a ByteArray and dissect that?
    -- collect the signals in a table for feathernet-as-signals dissectors?
    for i = 1, numqual:uint(), 1 do
        local namesize = buffer(offset,1):uint()
        local qual = tree:add(qual_pfield, buffer(offset, namesize+1), buffer(offset+1, namesize):string())
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

    (pinfo.columns.info--[[@as Column]]):append(string.format(" NQual=%i NSig=%i", numqual:uint(), nsig))
end
msgtype_dt:add(1, raw_proto)

local packed_proto = Proto("featherbridge.packed","FeatherBridge Packed Signals")
local packed_dt = DissectorTable.new("featherbridge.packed", "FeatherBridge Packed Signals", ftypes.UINT32)
function packed_proto.dissector(buffer,pinfo,tree)
    local head = fnet_header(buffer(0,12), pinfo, tree)
    local dis = packed_dt:get_dissector(head.protoid) or data_dis
    dis:call(buffer(12):tvb(), pinfo, tree)
end
msgtype_dt:add(2, packed_proto)

local fcp_proto = Proto("feathernet_control","FeatherNet Control Protocol")

local fcp_msgtype = {
    [1] = "Solicit",
    [2] = "Advertise",
}
local fcp_mtype_pfield = ProtoField.int32("feathernet_control.msgtype", "Message Type", base.DEC, fcp_msgtype)
local fcp_subject_pfield = ProtoField.uint32("feathernet_control.subject", "Subject", base.HEX)
local fcp_flags_pfield = ProtoField.uint32("feathernet_control.flags", "flags", base.HEX)
fcp_proto.fields = {
    fcp_mtype_pfield,
    fcp_subject_pfield,
    fcp_flags_pfield,
}

function fcp_proto.dissector(buffer,pinfo,tree)
    pinfo.columns.protocol = "FCP"

    local mtype = buffer(0,4)
    tree:add(fcp_mtype_pfield, mtype:int())
    local subject = buffer(4,4)
    tree:add(fcp_subject_pfield, subject:uint())

    pinfo.columns.info = string.format("%s %x", fcp_msgtype[mtype:int()] or "UNK", subject:uint())

    if buffer:len() >= 12 then
        local flags = buffer(8,4)
        tree:add(fcp_flags_pfield, flags:uint())
        pinfo.columns.info--[[@as Column]]:append(string.format(" flags %x", flags:uint()))
    end

end
packed_dt:add(2,fcp_proto)

local mapreq_proto = Proto("feathernet_mapreq","FeatherNet Map Request")
local mapreqid_pfield = ProtoField.uint32("feathernet_mapreq.id", "Map ID", base.HEX)
mapreq_proto.fields = {
    mapreqid_pfield,
}
function mapreq_proto.dissector(buffer,pinfo,tree)
    pinfo.columns.protocol = "MapReq"

    local id = buffer(0,4)
    tree:add(mapreqid_pfield, id:uint())
    pinfo.columns.info = string.format("Request Map %x", id:uint())
end
packed_dt:add(3,mapreq_proto)

local peerinfo_proto = Proto("featherbridge.peerinfo","FeatherBridge Peer Info")

local peerversion_pfield = ProtoField.string("featherbridge.peerinfo.version", "Version")
local bridgeid_pfield = ProtoField.uint32("featherbridge.peerinfo.bridgeid", "Bridge ID", base.HEX)
local player_pfield = ProtoField.uint32("featherbridge.peerinfo.player", "Player ID", base.DEC)
local port_pfield = ProtoField.uint32("featherbridge.peerinfo.port", "Port", base.DEC)
local opt_pfield = ProtoField.none("featherbridge.peerinfo.opt", "Option")

local peeropt_names = {
    [1] = "Last Known Partner",
    [2] = "Other Known Peers",
}
local opttype_pfield = ProtoField.uint8("featherbridge.peerinfo.opt.type", "Option Type", base.DEC, peeropt_names)
local optsize_pfield = ProtoField.uint8("featherbridge.peerinfo.opt.size", "Option Size", base.DEC )

local partid_pfield = ProtoField.uint8("featherbridge.peerinfo.opt.partner.bridgeid", "Bridge ID", base.HEX)
local myplayer_pfield = ProtoField.uint32("featherbridge.peerinfo.opt.my.player", "Player ID", base.DEC)
local myport_pfield = ProtoField.uint32("featherbridge.peerinfo.opt.my.port", "Port", base.DEC)
local partplayer_pfield = ProtoField.uint32("featherbridge.peerinfo.opt.partner.player", "Player ID", base.DEC)
local partport_pfield = ProtoField.uint32("featherbridge.peerinfo.opt.partner.port", "Port", base.DEC)
local partlastinfo_pfield = ProtoField.uint16("featherbridge.peerinfo.opt.partner.last_info", "Last Info", base.DEC)
local partlastdata_pfield = ProtoField.uint16("featherbridge.peerinfo.opt.partner.last_data", "Last Data", base.DEC)

peerinfo_proto.fields = {
    peerversion_pfield,
    bridgeid_pfield,
    player_pfield,
    port_pfield,
    opt_pfield,
    opttype_pfield,
    optsize_pfield,
    partid_pfield,
    myplayer_pfield,
    myport_pfield,
    partplayer_pfield,
    partport_pfield,
    partlastinfo_pfield,
    partlastdata_pfield,
}

---@param buffer TvbRange
---@return string
local function read_version(buffer)
    return string.format("%i.%i.%i", buffer(0,2):uint(), buffer(2,2):uint(), buffer(4,2):uint())
end

---@type {[integer]:fun(buffer:TvbRange, pinfo:Pinfo, tree:TreeItem)}
local peeropts_dissect = {
    [1] = function(buffer, pinfo, tree)
        tree:add(partid_pfield, buffer(0,4))
        tree:add(partplayer_pfield, buffer(4,4))
        tree:add(partport_pfield, buffer(8,2))
        tree:add(partlastinfo_pfield, buffer(10,2))
        tree:add(partlastdata_pfield, buffer(12,2))

        tree:set_text(string.format("Last Known Partner: %x", buffer(0,4):uint()))
        pinfo.columns.info--[[@as Column]]:append(string.format(" → %x:%i:%i", buffer(0,4):uint(), buffer(4,4):uint(), buffer(8,2):uint() ))
    end,
    [2] = function(buffer, pinfo, tree)
        tree:add(myplayer_pfield, buffer(0,4))
        tree:add(myport_pfield, buffer(4,2))
        tree:add(partid_pfield, buffer(6,4))
        tree:add(partplayer_pfield, buffer(10,4))
        tree:add(partport_pfield, buffer(14,2))
        tree:add(partlastinfo_pfield, buffer(16,2))
        tree:add(partlastdata_pfield, buffer(18,2))

        tree:set_text(string.format("Other Known Peer: %x", buffer(6,4):uint()))
    end,

}

function peerinfo_proto.dissector(buffer,pinfo,tree)
    local version = buffer(0,6)
    tree:add(peerversion_pfield, version, read_version(version))
    local bridgeid = buffer(6,4)
    tree:add(bridgeid_pfield, bridgeid)
    local player = buffer(10,4)
    tree:add(player_pfield, player)
    local port = buffer(14,2)
    tree:add(port_pfield, port)

    pinfo.columns.info = string.format("PeerInfo %x:%i:%i", bridgeid:uint(), player:int(), port:uint())

    if buffer:len() == 16 then return end

    
    local tlvs = buffer(16)
    while tlvs:len() > 0 do
        local otype = tlvs(0,1)
        local size = tlvs(1,2)
        local data = tlvs(3,size:uint())

        local thisopt = tlvs(0,3+size:uint())
        local option = tree:add(opt_pfield, thisopt)
        
        option:add(opttype_pfield, otype)
        option:add(optsize_pfield, size)

        local dissect = peeropts_dissect[otype:uint()]
        if dissect then
            dissect(data, pinfo, option)
        else
            data_dis:call(data:tvb(), pinfo, option)
        end
        if tlvs:len()==thisopt:len() then
            break
        end
        tlvs = tlvs(thisopt:len())
    end
end
msgtype_dt:add(3, peerinfo_proto)

DissectorTable.get("udp.port"):add_for_decode_as(featherbridge_proto)