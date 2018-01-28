﻿
Collision detection is achieved by the use of a canary signal on `signal-black`. This signal MUST be set to 1 on all transmitted messages. A receiving node MUST discard any messages received with values other than 1, or report them as errors.

If a collision is detected while transmitting, the transmitting node MAY retransmit the frame, but it MUST wait a delay period first. This delay MUST vary and SHOULD increase on subsequent retries. [TODO: describe LCG and entropy feed]

Packet Structure

|  Signal      | Fields                    | Notes       |
|--------------|---------------------------|-------------|
| signal-black | Collision Detection       | always=1    |
| signal-grey  | Destination Address       | 0=Broadcast |
| signal-white | Protocol Type             |             |

The primary Feathernet header is located on `signal-black`, `signal-grey`, and `signal-white`, in order to leave free as many signals as possible for raw-signal mode. Specifically, These were chosen to avoid vanilla color signals and signals used by Signal Strings, allowing transmission of string-based packets. Item and fluid signals were also avoided to allow transmission of logistic network reports or request lists without the need for additional filtering.

All nodes MUST listen for packets addressed to the Broadcast address, `0`. In addition, nodes may selectively listen for packets sent to one or more specific addresses. Multiple nodes MAY use the same address, IF the addresses are derived from higher layer addresses longer than 32bits, but the higher layer will receive the packets for each other node sharing a Feathernet address.

To allow higher layer protocols to support varied packet structures (reasonably large byte-stream packets, Signal Strings, and full item lists), multiple framing styles are defined, selected by the Protocol Type field.


| Protocol Type | Protocol               |
|---------------|------------------------|
| 0x000000      | raw signals            |
| 0x000001      | IPv6 on vanilla signals|
| 0x000002      | Feathernet Control     |




Feathernet Control

|  Signal      | Fields                    |
|--------------|---------------------------|
| signal-0     | Message Type              |
| signal-1     | Subject Address           |

| Message Type |                           |
|--------------|---------------------------|
| 1            | Neighbor Solicit          |
| 2            | Neighbor Advertise        |


When a node comes up without an address, it MAY select one automatically. To do this, the node takes the output of it's RNG as a candidate address, and broadcasts a Neighbor Solicit for that address. If no node answers within 180 ticks, the node broadcasts a Neighbor Advertise itself. If the node receives a Neighbor Advertise in response to the Solicit, it selects a new candidate address and starts again.

When any node receives a Neighbor Solicit for it's own address, it MUST respond with a Neighbor Advertise as soon as possible.




IPv6 

|  vanilla | custom            | Header Fields                  | Notes            |
|----------|-------------------|--------------------------------|------------------|
| signal-0 | signal-ip6magic   | version:trafficclass:flowlabel | const 0x60000000 = 1610612736 |
| signal-1 | signal-ip6lentype | payloadlength:nexthead:hoplim  | `nexthead = (signal & 0xff00) >> 8` `payloadlength = (signal >> 16) & 0xffff` |
| signal-2 | signal-ip6src1    | source address                 | High             |
| signal-3 | signal-ip6src2    | source address                 | Middle High      |
| signal-4 | signal-ip6src3    | source address                 | Middle Low       |
| signal-5 | signal-ip6src4    | source address                 | Low              |
| signal-6 | signal-ip6dst1    | destination address            | High             |
| signal-7 | signal-ip6dst2    | destination address            | Middle High      |
| signal-8 | signal-ip6dst3    | destination address            | Middle Low       |
| signal-9 | signal-ip6dst4    | destination address            | Low              |

Nodes MUST configure an address in fe80::/64. Nodes MAY also configure addresses under prefixes advertised on the link by routers, or added via manual configuration.

ICMPv6

| virtual  |  custom          | Fields |
|----------|------------------|---------------|
| signal-A | signal-icmp6head | type:code:checksum |
| signal-B | signal-icmp6data | Data |

Ping/Pong

| virtual  |  custom          | Fields |
|----------|------------------|---------------|
| signal-A | signal-icmp6head | type:code:checksum |
| signal-B | signal-icmp6data | identifier:sequence |
|   ...    |                  | payload |

Route Advertisement

| virtual  |  custom          | Fields |
|----------|------------------|---------------|
| signal-A | signal-icmp6head | type:code:checksum |
| signal-B | signal-icmp6data | hoplim8:flags8:routerlifetime16 |
| signal-C |                  | reachabletime |
| signal-D |                  | retranstime |
| signal-E |                  | options... |
|   ...    |                  | options... |

| offset | Fields |
|--------|------------------|---------------|
|    0   | type:length:data |
|    1   | data |
|   ...  | data ... |

Length is in pairs of signals (8 bytes)

Implement at least:

  * source link layer
	* type = 1
    * feathernet address is 4 bytes, which gets split across signals
  * prefix information
    * type = 3
    * 0 = type:length:prefixlen8:L1:A1:reserved
    * 1 = valid lifetime : seconds prefix is valid for
    * 2 = preferred lifetime : seconds prefix is preferred for
    * 3 = reserved
    * 4-7 = prefix data
	

UDP

| virtual  |  custom         | Fields |
|----------|-----------------|---------------|
| signal-A | signal-udpports | source port : destination port |
| signal-B | signal-udplen   | length : checksum |


Complete Signal order for IPv6 on vanilla signals

In order to provide a mapping from the bytes in a packet to signals, it is neccesary to put the signals in a consistent order. Ideally, only Vanilla signals would be considered for this, for maximum compatibility, but this produces an MTU which is not sufficient for IPv6. The order of Vanilla signals is specified here, and a mod[TODO] is provided which creates the additional signals required to reach a MTU of 1280 as required by IPv6. Additionally, blueprints are provided [TODO] for converting an index and value to the given signal and vice versa.

`signal-white`, `signal-grey`, and `signal-black` are left unordered, as these are used by the Feathernet link layer header.

| index | signal |
|-------|--------|
|    0  |signal-0|
|    1  |signal-1|
|    2  |signal-2|
|    3  |signal-3|
|    4  |signal-4|
|    5  |signal-5|
|    6  |signal-6|
|    7  |signal-7|
|    8  |signal-8|
|    9  |signal-9|
|   10  |signal-A|
|   11  |signal-B|
|   12  |signal-C|
|   13  |signal-D|
|   14  |signal-E|
|   15  |signal-F|
|   16  |signal-G|
|   17  |signal-H|
|   18  |signal-I|
|   19  |signal-J|
|   20  |signal-K|
|   21  |signal-L|
|   22  |signal-M|
|   23  |signal-N|
|   24  |signal-O|
|   25  |signal-P|
|   26  |signal-Q|
|   27  |signal-R|
|   28  |signal-S|
|   29  |signal-T|
|   30  |signal-U|
|   31  |signal-V|
|   32  |signal-W|
|   33  |signal-X|
|   34  |signal-Y|
|   35  |signal-Z|
|   36  |signal-red|
|   37  |signal-green|
|   38  |signal-blue|
|   39  |signal-yellow|
|   40  |signal-pink|
|   41  |signal-cyan|
|   42  |water|
|   43  |crude-oil|
|   44  |steam|
|   45  |heavy-oil|
|   46  |light-oil|
|   47  |petroleum-gas|
|   48  |sulfuric-acid|
|   49  |lubricant|
|   50  |wooden-chest|
|   51  |iron-chest|
|   52  |steel-chest|
|   53  |storage-tank|
|   54  |transport-belt|
|   55  |fast-transport-belt|
|   56  |express-transport-belt|
|   57  |underground-belt|
|   58  |fast-underground-belt|
|   59  |express-underground-belt|
|   60  |splitter|
|   61  |fast-splitter|
|   62  |express-splitter|
|   63  |burner-inserter|
|   64  |inserter|
|   65  |long-handed-inserter|
|   66  |fast-inserter|
|   67  |filter-inserter|
|   68  |stack-inserter|
|   69  |stack-filter-inserter|
|   70  |small-electric-pole|
|   71  |medium-electric-pole|
|   72  |big-electric-pole|
|   73  |substation|
|   74  |pipe|
|   75  |pipe-to-ground|
|   76  |pump|
|   77  |rail|
|   78  |train-stop|
|   79  |rail-signal|
|   80  |rail-chain-signal|
|   81  |locomotive|
|   82  |cargo-wagon|
|   83  |fluid-wagon|
|   84  |artillery-wagon|
|   85  |car|
|   86  |tank|
|   87  |logistic-robot|
|   88  |construction-robot|
|   89  |logistic-chest-active-provider|
|   90  |logistic-chest-passive-provider|
|   91  |logistic-chest-storage|
|   92  |logistic-chest-buffer|
|   93  |logistic-chest-requester|
|   94  |roboport|
|   95  |small-lamp|
|   96  |red-wire|
|   97  |green-wire|
|   98  |arithmetic-combinator|
|   99  |decider-combinator|
|  100  |constant-combinator|
|  101  |power-switch|
|  102  |programmable-speaker|
|  103  |stone-brick|
|  104  |concrete|
|  105  |hazard-concrete|
|  106  |landfill|
|  107  |cliff-explosives|
|  108  |iron-axe|
|  109  |steel-axe|
|  110  |repair-pack|
|  111  |blueprint|
|  112  |deconstruction-planner|
|  113  |blueprint-book|
|  114  |boiler|
|  115  |steam-engine|
|  116  |steam-turbine|
|  117  |solar-panel|
|  118  |accumulator|
|  119  |nuclear-reactor|
|  120  |heat-exchanger|
|  121  |heat-pipe|
|  122  |burner-mining-drill|
|  123  |electric-mining-drill|
|  124  |offshore-pump|
|  125  |pumpjack|
|  126  |stone-furnace|
|  127  |steel-furnace|
|  128  |electric-furnace|
|  129  |assembling-machine-1|
|  130  |assembling-machine-2|
|  131  |assembling-machine-3|
|  132  |oil-refinery|
|  133  |chemical-plant|
|  134  |centrifuge|
|  135  |lab|
|  136  |beacon|
|  137  |speed-module|
|  138  |speed-module-2|
|  139  |speed-module-3|
|  140  |effectivity-module|
|  141  |effectivity-module-2|
|  142  |effectivity-module-3|
|  143  |productivity-module|
|  144  |productivity-module-2|
|  145  |productivity-module-3|
|  146  |raw-wood|
|  147  |coal|
|  148  |stone|
|  149  |iron-ore|
|  150  |copper-ore|
|  151  |uranium-ore|
|  152  |raw-fish|
|  153  |wood|
|  154  |iron-plate|
|  155  |copper-plate|
|  156  |solid-fuel|
|  157  |steel-plate|
|  158  |plastic-bar|
|  159  |sulfur|
|  160  |battery|
|  161  |explosives|
|  162  |crude-oil-barrel|
|  163  |heavy-oil-barrel|
|  164  |light-oil-barrel|
|  165  |lubricant-barrel|
|  166  |petroleum-gas-barrel|
|  167  |sulfuric-acid-barrel|
|  168  |water-barrel|
|  169  |copper-cable|
|  170  |iron-stick|
|  171  |iron-gear-wheel|
|  172  |empty-barrel|
|  173  |electronic-circuit|
|  174  |advanced-circuit|
|  175  |processing-unit|
|  176  |engine-unit|
|  177  |electric-engine-unit|
|  178  |flying-robot-frame|
|  179  |satellite|
|  180  |rocket-control-unit|
|  181  |low-density-structure|
|  182  |rocket-fuel|
|  183  |nuclear-fuel|
|  184  |uranium-235|
|  185  |uranium-238|
|  186  |uranium-fuel-cell|
|  187  |used-up-uranium-fuel-cell|
|  188  |science-pack-1|
|  189  |science-pack-2|
|  190  |science-pack-3|
|  191  |military-science-pack|
|  192  |production-science-pack|
|  193  |high-tech-science-pack|
|  194  |space-science-pack|
|  195  |pistol|
|  196  |submachine-gun|
|  197  |shotgun|
|  198  |combat-shotgun|
|  199  |rocket-launcher|
|  200  |flamethrower|
|  201  |land-mine|
|  202  |firearm-magazine|
|  203  |piercing-rounds-magazine|
|  204  |uranium-rounds-magazine|
|  205  |shotgun-shell|
|  206  |piercing-shotgun-shell|
|  207  |cannon-shell|
|  208  |explosive-cannon-shell|
|  209  |uranium-cannon-shell|
|  210  |explosive-uranium-cannon-shell|
|  211  |artillery-shell|
|  212  |rocket|
|  213  |explosive-rocket|
|  214  |atomic-bomb|
|  215  |flamethrower-ammo|
|  216  |grenade|
|  217  |cluster-grenade|
|  218  |poison-capsule|
|  219  |slowdown-capsule|
|  220  |defender-capsule|
|  221  |distractor-capsule|
|  222  |destroyer-capsule|
|  223  |discharge-defense-remote|
|  224  |artillery-targeting-remote|
|  225  |light-armor|
|  226  |heavy-armor|
|  227  |modular-armor|
|  228  |power-armor|
|  229  |power-armor-mk2|
|  230  |solar-panel-equipment|
|  231  |fusion-reactor-equipment|
|  232  |energy-shield-equipment|
|  233  |energy-shield-mk2-equipment|
|  234  |battery-equipment|
|  235  |battery-mk2-equipment|
|  236  |personal-laser-defense-equipment|
|  237  |discharge-defense-equipment|
|  238  |exoskeleton-equipment|
|  239  |personal-roboport-equipment|
|  240  |personal-roboport-mk2-equipment|
|  241  |night-vision-equipment|
|  242  |stone-wall|
|  243  |gate|
|  244  |gun-turret|
|  245  |laser-turret|
|  256  |flamethrower-turret|
|  257  |radar|
|  258  |rocket-silo|		 