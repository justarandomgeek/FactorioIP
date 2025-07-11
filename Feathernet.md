﻿
# Feathernet: Autoconfigured Native and IPv6 Networking over Factorio Circuit Networks

Feathernet is a protocol (and implementation) for transmitting packet based data (native Factorio signals, or IP packets) between many nodes over a single shared wire. FeatherBridge extends this with a link-layer switch operating across surfaces, between worlds, and to/from an IP network.

## Packet Structure

|  Signal       | Fields                    | Notes       |
|---------------|---------------------------|-------------|
| signal-check  | Collision Detection       | always=1    |
| signal-info   | Protocol Type             |             |
| signal-output | Source Address            |             |
| signal-input  | Destination Address       | 0=Broadcast |

The primary Feathernet header is located on `signal-check`, `signal-info`, `signal-output`, and `signal-input`, in order to leave free as many signals as possible for raw-signal mode. Specifically, These were chosen to avoid vanilla color and alphanumeric signals to allow for lamp and display panel based display messages, as well as avoiding item and fluid signals to allow transmission of logistic network reports or requests without the need for additional filtering or transformation.

Collision detection is achieved by the use of a canary signal on `signal-check`. This signal MUST be set to 1 on all transmitted messages. A receiving node MUST discard any messages received with values other than 1, or report them to higher layers as errors.

If a collision is detected while transmitting, the transmitting node MAY choose to retransmit the frame, but it MUST wait a delay period first. This delay MUST vary and SHOULD increase on subsequent retries.

All nodes MUST listen for packets addressed to the Broadcast address, `0`. In addition, nodes may selectively listen for packets sent to one or more specific addresses, either manually or automaticaly configured.

To allow higher layer protocols to support varied packet structures (reasonably large byte-stream packets, virtual signal messages, and full item lists), multiple framing styles can be defined, selected by the Protocol Type field.

| Protocol Type | Protocol               |
|---------------|------------------------|
|             0 | raw signals            |
|             1 | IPv6 on vanilla signals|
|             2 | Feathernet Control     |
|           3-5 | Signal Map Transfer    |

## Feathernet Control

Feathernet Control Protocol provides link-layer configuration services, including auto-addressing and neighbor discovery.

|  Signal      | Fields                    |
|--------------|---------------------------|
| signal-0     | Message Type              |
| signal-1 ... | Data                      |

| Message Type |                           |
|--------------|---------------------------|
| 1            | Neighbor Solicit          |
| 2            | Neighbor Advertise        |

When a node comes up without an address, it MAY select one automatically. To do this, the node takes a random number as a candidate address, and broadcasts a Neighbor Solicit for that address. If no node answers within 180 ticks, the node broadcasts a Neighbor Advertise itself. If the node receives a Neighbor Advertise in response to the Solicit, it selects a new candidate address and starts again.

When any node receives a Neighbor Solicit for it's own address, it MUST respond with a Neighbor Advertise. Bridging and routing nodes may also respond to a Solicit for 0/Broadcast.

For Neighbor Solicit the data is the subject node address:

|  Signal      | Fields                    |
|--------------|---------------------------|
| signal-0     | Message Type = 1          |
| signal-1     | Subject Address           |

For Neighbor Advertise, the data is the subject node address, and some node information:

|  Signal      | Fields                    |
|--------------|---------------------------|
| signal-0     | Message Type = 2          |
| signal-1     | Subject Address           |
| signal-2     | Flags                     |

Flags:

| Value      | Purpose                        |
|------------|--------------------------------|
| 0x00000001 | IP Tunnel Active               |
| 0x00000002 | Supports Signal Map Transfer   |

## FeatherBridge Peering

FeatherBridge switches on games running on the same PC may peer with each other and exchange packets directly. All messages between peers begin with a one byte message-type.

| type | Mesage Type      |
|------|------------------|
|    1 | Raw Signal Data  |

TODO: packed FCP message? peer liveness checks/loop check?

### Raw Signal Data

Carries any packet not covered by a dedicated packed format

| type   | Field                |
|--------|----------------------|
| uint8  | Message Type = 0x01  |
| int32  | Protocol ID          |
| int32  | Source Address       |
| int32  | Dest Address         |
| uint8  | Num Quality Sections |

Quality Section Header:

| type     | Field         |
|----------|---------------|
| string8  | Quality Name  |
| uint16   | Num Signals   |

Signal Entry:

| type     | Field       |
|----------|-------------|
| uint8    | Type (enum) |
| string8  | Name        |
| int32    | Value       |

string8 = string prefixed by uint8 length (lua pack type `s1`)

## Signal Map Transfer

To support protocols that require an ordered stream of data (such as IP), an ordered map of the signals must be shared among devices. A node that supports Map Transfer should indicate this capability in FCP Advertise messages. A host may broadcast FCP Solicit to find such nodes.

### Map Request

|  Signal      | Fields                     |
|--------------|----------------------------|
| signal-info  | Protocol ID = 3            |
| entity/item-request-proxy  | Map ID       |

This should be sent unicast to a host that has previously advertised the capability.

### Map Transfer

|  Signal      | Fields                    |
|--------------|---------------------------|
| signal-info  | Protocol ID = 4           |
| entity/item-request-proxy  | Map ID      |

All signals not reserved by this header or the Feathernet header contain their own index (+1 to prevent the zeroth signal from being dropped) in the map.

### Extended Map Transfer

|  Signal      | Fields                      |
|--------------|-----------------------------|
| signal-info  | Protocol ID = 5             |
| entity/item-request-proxy  | Map ID        |
| index 0      | Index for (collision)       |
| index 1      | Index for (protocol)        |
| index 2      | Index for (source address)  |
| index 3      | Index for (dest address)    |
| index 4      | Index for (MapID)           |

If a map provider wishes to include indexes for the reserved header signals, they can be provided as a second message, using the indexes in the first.

## IPv6

IPv6 structure is as described in RFC8200 (prev RFC2460), with an example header here (assuming no options) for reference using the reference implemention's signal map. Signals are assembled big-endian from bytes on the wire - the first byte to come in off the wire is the highest byte of the signal. The last signal will be padded with 0s in the low bytes if required to make a full 32bit word.

|   signal | Header Fields                  | Notes            |
|----------|--------------------------------|------------------|
| signal-0 | version:trafficclass:flowlabel | const 0x60000000 = 1610612736 |
| signal-1 | payloadlength:nexthead:hoplim  | `nexthead = (signal & 0xff00) >> 8` `payloadlength = (signal >> 16) & 0xffff` |
| signal-2 | source address                 | High             |
| signal-3 | source address                 | Middle High      |
| signal-4 | source address                 | Middle Low       |
| signal-5 | source address                 | Low              |
| signal-6 | destination address            | High             |
| signal-7 | destination address            | Middle High      |
| signal-8 | destination address            | Middle Low       |
| signal-9 | destination address            | Low              |

Nodes MUST configure an address in fe80::/64. Nodes MAY also configure addresses under prefixes advertised on the link by routers, or added via manual configuration.

### ICMPv6

ICMPv6 and NDP are defined in RFC4443 and RFC4861, with example headers provided here (assuming no IPv6 options) for reference.

|  signal  | Fields |
|----------|---------------|
| signal-A | type:code:checksum |
| signal-B | Data |

#### Ping/Pong

|  signal  | Fields |
|----------|---------------|
| signal-A | type:code:checksum |
| signal-B | identifier:sequence |
|   ...    | payload |

#### Route Advertisement

|  signal  | Fields |
|----------|---------------|
| signal-A | type:code:checksum |
| signal-B | hoplim8:flags8:routerlifetime16 |
| signal-C | reachabletime |
| signal-D | retranstime |
| signal-E | options... |
|   ...    | options... |

| offset | Fields |
|--------|------------------|
|    0   | type:length:data |
|    1   | data |
|   ...  | data ... |

Length is in pairs of signals (8 bytes)

* source link layer
  * type = 1
  * openwrt puts useless info in this for gre-over-v6 tunnel (top 6 bytes of outer address), so ignore it; just use the actual link-layer source.
* prefix information
  * type = 3
  * 0 = type:length:prefixlen8:L1:A1:reserved
  * 1 = valid lifetime : seconds prefix is valid for
  * 2 = preferred lifetime : seconds prefix is preferred for
  * 3 = reserved
  * 4-7 = prefix data
* DNS Server
  * type = 25
  * 0 = type:length:reserved
  * 1 = lifetime (seconds)
  * 2-5 = address

### UDP

UDP is defined in RFC768, with an example header provided here (assuming no IPv6 options) for reference.

|  signal  | Fields |
|----------|---------------|
| signal-A | source port : destination port |
| signal-B | length : checksum |
| signal-C | data |
|    ...   | data... |

### Signal List Format

Due to the number of signals taken up by protocol headers, it is impractical to use raw signals beyond link-local scope. To facilitate such signalling on wider scales, a Signal List format is defined, to allow embedding arbitrary signals at arbitrary locations in the packet. Signal List may be used as a payload in any protocol that supports binary payload data, such as UDP.

| offset | Fields |
|--------|------------------|
|    0   | type:count:signalID|
|    1   | data |
|   ...  | data ... |

A Signal List is composed of a single header signal, followed by one or more signal values. The header signal contains three fields:

* `type`: 8 bit type
  * 0x00: signal values
    * zero count indicates end of list-of-lists
  * 0x01: Map ID
    * count=0, signalID=MapID for subsequent lists
* `count`: 8 bit count of sequential data signals
* `signalID`: 16 bit signal ID from signal map

To support non-sequential signals, an application may also use a list of Signal Lists, simply placing them one after another. Due to the `type` and `count` fields, a valid Signal List header will always be non-zero, allowing easy identification of the end of a list-of-lists.

## Implementation

### FeatherBridge

![FeatherBridge](Screenshots/FeatherBridge.png)

Inside Factorio, each FeatherBridge combinator is simply connected to the main link wire for its local segment, such as a planet's radar-wire link, and each will act as a switch port on the bridge. The bridge will randomly select an address, which may be discovered by FCP Neighbor Discovery.

FeatherBridge can also connect directly to other local games to forward any circuit signal packets. Bridges will periodically exchange PeerInfo, and forward circuit packets as long as their partner appears live.

FeatherBridge does not (yet) do any loop detection, so the user is responsible for not creating loops in either the circuit network or peering links.

The FeatherBridge IP Tunnel is a GRE tunnel relayed to a local router by [`socat`](http://www.dest-unreach.org/socat/):

```sh
socat udp:localhost:$factorio_port,bind=localhost:$local_port ip6:$router_ip:47,bind=$local_ip
```

FeatherBridge supports receiving and re-sharing a prepared signal map of 375 signals (1500 bytes) via Signal Map Transfer, which will be used when translating ordered data packets to/from the IP network port. FeatherBridge ignores (and does not send) the Extended Map message with header signal indexes, and only supports a single map (mapid=0), but other devices on the network may use other maps for non-IP traffic or for Signal List messages over IP.

### Factorio - Feathernet Link Layer

#### Receiver

![LL Receiver](Screenshots/LLRecv.png)

The Feathernet receiver is simply a filter checking for collision detect=1 and destination equal to broadcast or the node's own address. Valid received packets are sent to higher layer protocols as they come in, unmodified.

#### Transmitter

![LL Transmitter](Screenshots/LLTrans.png)

TODO: replace the one input fifo with a priority queue in case multiple modules try to transmit at once. FCP first, then Ping, then one or two "user" slots

The Feathernet Tramsitter manages sending packets out onto the bus. Incoming packets (from higher layer circuits) are queued in a small FIFO memory, and transmitted by the collision-detection state machine. The Transmitter also contains the RNG, which is provided as an output for other modules to use as required.

### Factorio - Protocol Layers

#### FCP Module

![FCP Module](Screenshots/FCP.png)

FCP allows nodes to self-configure unique addresses. For non-IP networks, the link layer and FCP modules are sufficient to provide basic networking, using Native Signals framing or other framing specified elsewhere.

The Neighbor Discovery (self) submodule will respond to a broadcast or unicast Solicit with an Advertise, to support Duplicate Address Detection for autoconfig.

The Neighbor Discovery (others) submodule listens for Advertise messages from other nodes, and records the most recent received address with the Router/Map Transfer flags. These addresses are provided to the link-layer config line.

The Autoconfiguration submodule performs address selection and Duplicate Address Detection broadcasts, and provides the selected address to the link-layer config line. Additionally, the FCP module provides red(unconfigured)/yellow(autoconf in progress)/green(autoconf completed) signals on the status line to indicate address selection state. Autoconfiguration must be triggered manually once the circuits have been constructed by pressing the Start AutoConf button.

#### Raw Signals Modules

![Raw Receiver](Screenshots/RawRx.png)

This module receives and holds the last frame sent to this node in Raw Signals mode.

![Raw Transmitter](Screenshots/RawTx.png)

This module can send arbitrary data in Raw Signals mode. There is a keypad for setting the destination and a constant combinator for payload data. Note that this module can also be used to send other protocols by including header signals in the data.

#### Map Transfer Modules

![Map Transfer Request](Screenshots/MTRequest.png)

The Map Transfer Request module will request and record the signal map from FeatherBridge using the last received FCP Advertise address with the IP Tunnel flag set. This is currently triggered manually.

![Map Generator](Screenshots/MapGen.png)

The Map Generator module assembles the signal map used in this document, for use with Map Transfer Sender.

![Map Transfer Sender](Screenshots/MTSender.png)

The Map Transfer Sender module sends (manually triggered) the generated map to a specified node (manually configure address, or connect config for last advertised bridge address). This is used once to complete FeatherBridge setup with a signal map, most nodes do not require this module.

#### IPv6 Module

![IP Module](Screenshots/IP.png)

The current IPv6 node supports recieving packets with up to five addresses: The link-local address, formed by fe80::/64 and the 32bit node identifier, The all-nodes broadcast address ff02::1, and up to three globally routable unicast addresses, formed by 64bit prefixes combined with the node identifier in the low 32 bits. Packets matching one of these addresses are forwarded to higher layer protocols, with quality-normal=NextHeader and quality-uncommon=PayloadSize added to the packet data. A check signal is also emitted on the metadata wire to signal a new packet, and Signal-A with the index of the matched address.

| Signal-A | Address         |
|----------|-----------------|
|        1 | fe80::/64       |
|        2 | ff02::1/128     |
|      3-5 | Global Prefixes |

Config Input Signals (more signals present not used here):

|  Signal  | Configuation Value |
|----------|--------------------|
| signal-0 | Prefix 3           |
| signal-1 | Prefix 3           |
| signal-2 | Prefix 4           |
| signal-3 | Prefix 4           |
| signal-4 | Prefix 5           |
| signal-5 | Prefix 5           |

#### IP Autoconfig Module

![IP Autoconfig Module](Screenshots/IPAutoconfig.png)

This module listens for Route Advertisement messages and autoconfigures addresses in up to three advertised subnets. It also records the rDNS server and Hop Limit values.

Config Output Signals:

|  Signal  | Configuation Value |
|----------|--------------------|
| signal-H | Hop Limit          |
| signal-0 | RA Prefix 1        |
| signal-1 | RA Prefix 1        |
| signal-2 | RA Prefix 2        |
| signal-3 | RA Prefix 2        |
| signal-4 | RA Prefix 3        |
| signal-5 | RA Prefix 3        |

#### Ping Reponder Module

![Ping Responder Module](Screenshots/Ping.png)

This module listens for a Ping sent to any of the addresses supported by the IPv6 module, and responds to it. Multicast will always be answered from the link-local address.

#### UDP Listener Module

![UDP Listener Module](Screenshots/UDP.png)

This module listens on a single UDP port and holds the last received packet
