
# Feathernet: Autoconfigured Native and IPv6 Networking over Factorio Circuit Networks

Feathernet is a protocol (and implementation) for transmitting packet based data (native Factorio signals, or IP packets) between many nodes over a single shared wire.

## Packet Structure

|  Signal      | Fields                    | Notes       |
|--------------|---------------------------|-------------|
| signal-check | Collision Detection       | always=1    |
| signal-dot   | Destination Address       | 0=Broadcast |
| signal-info  | Protocol Type             |             |

The primary Feathernet header is located on `signal-check`, `signal-dot`, and `signal-info`, in order to leave free as many signals as possible for raw-signal mode. Specifically, These were chosen to avoid vanilla color signals and signals used by Signal Strings, allowing transmission of string-based packets. Item and fluid signals were also avoided to allow transmission of logistic network reports or request lists without the need for additional filtering.

Collision detection is achieved by the use of a canary signal on `signal-check`. This signal MUST be set to 1 on all transmitted messages. A receiving node MUST discard any messages received with values other than 1, or report them as errors.

If a collision is detected while transmitting, the transmitting node MAY retransmit the frame, but it MUST wait a delay period first. This delay MUST vary and SHOULD increase on subsequent retries.

All nodes MUST listen for packets addressed to the Broadcast address, `0`. In addition, nodes may selectively listen for packets sent to one or more specific addresses.

To allow higher layer protocols to support varied packet structures (reasonably large byte-stream packets, Signal Strings, and full item lists), multiple framing styles are defined, selected by the Protocol Type field.

| Protocol Type | Protocol               |
|---------------|------------------------|
|             0 | raw signals            |
|             1 | IPv6 on vanilla signals|
|             2 | Feathernet Control     |

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
| signal-0     | Message Type              |
| signal-1     | Subject Address           |

For Neighbor Advertise, the data is the subject node address, and some node information:

|  Signal      | Fields                    |
|--------------|---------------------------|
| signal-0     | Message Type              |
| signal-1     | Subject Address           |
| signal-2     | Flags                     |

Flags:
0x00000001 Router


## IPv6

IPv6 structure is as described in RFC8200 (prev RFC2460), with an example header here (assuming no options) for reference. Signals are assembled big-endian from bytes on the wires - the first byte to come in off the wire is the highest byte of the signal. The last signal will be padded with 0s in the low bytes if required to make a full 32bit word.

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
    * openwrt puts useless info in this for gre-over-v6 tunnel (top 6 bytes of outer address), so ignore it?
  * prefix information
    * type = 3
    * 0 = type:length:prefixlen8:L1:A1:reserved
    * 1 = valid lifetime : seconds prefix is valid for
    * 2 = preferred lifetime : seconds prefix is preferred for
    * 3 = reserved
    * 4-7 = prefix data


### UDP

UDP is defined in RFC768, with an example header provided here (assuming no IPv6 options) for reference.

|  signal  | Fields |
|----------|---------------|
| signal-A | source port : destination port |
| signal-B | length : checksum |
| signal-C | data |
|    ...   | data... |


### Signal order for IPv6 on vanilla signals

In order to provide a mapping from the bytes in a packet to signals, it is neccesary to put the signals in a consistent order. Ideally, only Vanilla signals would be considered for this, for maximum compatibility, but this produces an MTU which is not sufficient for IPv6. The order of Vanilla signals is specified here, and a mod is provided which creates the additional signals required to reach a MTU of 1280 as required by IPv6. Signals beyond the vanilla list are simply `signal-n` where `n` is the index, such as `signal-249`, `signal-250`, `signal-319`. Additionally, blueprints are provided for an implementation of converting an index and value to the given signal and vice versa.

`signal-white`, `signal-grey`, and `signal-black` are left unordered, as these are used by the Feathernet link layer header.

To accomodate multiple versions of the game, signal maps are per major version.

  *  [Signal Map for 0.16](./SignalMap_16.md)
  *  [Signal Map for 0.17](./SignalMap_17.md)



### Signal List Format

Due to the number of signals taken up by protocol headers, it is impractical to use raw signals beyond link-local scope. To facilitate such signalling on wider scales, a Signal List format is defined, to allow embedding arbitrary singals at arbitrary locations in the packet. Signal List may be used as a payload in any protocol that supports binary payload data, such as UDP.

| offset | Fields |
|--------|------------------|
|    0   | flags:count:signalID|
|    1   | data |
|   ...  | data ... |

A Signal List is composed of a single header signal, followed by one or more signal values. The header signal contains three fields:

 * `flags`: 8 bit control flags
   * All undefined flag bits MUST be set to 0.
 * `count`: 8 bit count of sequential data signals
 * `signalID`: 16 bit signal ID
   * 0-319 defined as per IPv6 above
   * 320-2047 reserved for ordered signal list expansion
   * 2048-4095 reserved for local use with modded signals
   * -1 = signal-grey
   * -2 = signal-white
   * -3 = signal-black
   * All unlisted values reserved for future use

To support non-sequential signals, an application may also use a list of Signal Lists, simply placing them one after another. Due to the `count` field, a valid Signal List header will always be non-zero, allowing easy identification of the end of a list-of-lists.

flag extended ids
flags:count
qual8:kind8:id16



## Implementation

### Factorio - Feathernet Link Layer
#### Receiver
![LL Receiver](Screenshots/LLRecv.png)

The Feathernet receiver is simply a filter checking for black=1 and destination equal to broadcast or the node's own address. The current implementation uses a node address of 1 until it is configured. Received packets are sent to higher layer protocols as they come in, with signal-black and signal-grey cleared for working space.

#### Transmitter
![LL Transmitter](Screenshots/LLTrans.png)

The Feathernet Tramsitter manages sending packets out onto the bus. Incoming packets (from higher layer circuits) are queued in a small FIFO memory, and transmitted by the collision-detection state machine. The Transmitter also contains the RNG, which is provided as an output for other modules to use as required. The Status line will have signal-blue set while the Transmitter is holding a packet which has not yet been transmitted.

##### RNG
Various protocols call for random numbers for various purposes. To accomodate this, the Transmitter includes a small LCG, with the parameters used by glibc (a=1103515245, c=12345) and outputting the low 31 bits as signal-R on the transmitter status wire. Due to the nature of combinators, there are three copies of this LCG running in parallel at different phases. When any packet is transmitted, all the signals in the frame are summed and added to the current value at each of the three stages, to accumulate entropy. The RNG cycles continously, and applications needing random numbers simply sample the current value when required.


### Factorio - Protocol Layers

#### FCP
![FCP Module](Screenshots/FCP.png)

FCP allows nodes to self-configure unique addresses. For non-IP networks, the link layer and FCP modules are sufficient to provide basic networking, using Native Signals framing or other framing specified elsewhere.

Autoconfiguration must be triggered manually once the circuits have been constructed by pressing the Start AutoConf button. The module will then perform FCP autoconfig as described above, and provide the selected address to the receiver. Additionally, the FCP module provides red(unconfigured)/yellow(autoconf in progress)/green(autoconf completed) signals on the status line to indicate address selection state.

#### IPv6
![IP Module](Screenshots/IP.png)

The current IPv6 node supports recieving packets with up to three addresses: The link-local address, formed by fe80::/64 and the 32bit node identifier, The all-nodes broadcast address ff02::1, and a globally routable unicast address, formed by a 64-96bit prefix and the node identifier. Packets matching one of these addresses are forwarded to higher layer protocols, with white=NextHeader and grey=PayloadSize.

|  Signal  | Configuation Value |
|----------|--------------------|
| signal-0 | Prefix             |
| signal-1 | Prefix             |
| signal-2 | Prefix             |
| signal-P | Prefix Length      |
| signal-T | Prefix Valid Time (ticks) |
| signal-R | Router Link-Layer Address |
| signal-H | Hop Limit          |



#### ICMP
![ICMP Module](Screenshots/ICMP.gif)
The current node supports ICMP Echo Request/Reply message, and will emit Replies to any received Requests. It also listens for Route Advertisements and will auto-configure a global prefix when one is received.

#### UDP
![UDP Listener Module](Screenshots/UDP.png)

UDP ports can be connected to various devices taking circuit inputs. For demonstration purposes, I have connected a small graphical display and a small music player.

##### Graphical Display
The graphical display takes images in a headerless [pbm](http://netpbm.sourceforge.net/doc/pbm.html). Small images (32 * 38 - height could be increased to by configuring additional rows of lamps) can be sent with a command such as `convert image.png pbm:-|cut -d$'\n' -f 3 | nc -6uvv  2001:DB8::cc9:dd27 1234`, with appropriate address/port.

##### Music Player
The music player takes a series of 32bit words each containing 5 consecutive 6 bit notes to play.

| Reserved | Note1 | Note2 | Note3 | Note4 | Note5 |
|----------|-------|-------|-------|-------|-------|
| two high bits always 00 | six bits 0-64 | six bits 0-64 | six bits 0-64 | six bits 0-64 | six bits 0-64 |

For each incoming packet, the payload data is played sequentially, one note every other tick, starting with the high-order note in each signal and advancing to the next signal after the lower-order note. After the last signal in a packet, the next buffered packet is played immediately. The note values are sent to a programmable speaker set to Piano, pitch is value.


### Clusterio Bridge

Circuit communication outside of factorio is acheived through [Clusterio](https://github.com/Danielv123/factorioClusterio#introduction), which provides an interface to send/receive signals between worlds via a small node.js application. IP communication is acheived by connecting to cluster with a custom bridge which converts circuit network frames to/from IP packets and exchanges with a local router over GRE. FCP packets are encoded as ethertype 0x88B5, which is reserved for local private experimentation. Do not forward these FCP packets beyond the GRE link. Forwarding FCP to clusterio is not required, but was at times useful for debugging - these will probably not be forwarded in the future with a more advanced router node.

![Clusterio Bridge](Screenshots/ClusterioBridge.png)

Inside Factorio, the Clusterio combinators are then connected in place of other protocol/application circuits to a slightly modified Feathernet receiver and standard transmitter. The receiver is modified to receive all FCP frames (with destination address preserved, unlike normal packets), and has a manually-configured address for sending packets directly out of the world. The address used is the address declared by the router in its Source Link Layer option in Route Advertisements - in my case, the IPv4 of the router's end of the GRE tunnel. The transmitter is configured to send only Clusterio packets originating from non-local worlds. This filter arrangement means all nodes should end up with unique feathernet addresses, even across worlds, and that broadcasts work across worlds. Unicast to nodes in another world is not currently supported.

### Future Additions

Various features are planned but not yet implemented in this version:

 * Packet generators for outbound UDP and Ping
 * More correct generation of Pong packets
 * More advanced Clusterio Bridge node
   * Actually route between worlds - treat clusterio as a separate link
     * routers as ::worl:d_id:0:1 within their world link
     * routers as ::0:0:worl:d_id on clusterio link
     * RA ::worl:d_id:0:0/96 to world link
 * Connect a decently fast CPU for TCP
