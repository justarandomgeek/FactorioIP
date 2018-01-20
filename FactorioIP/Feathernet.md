
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



UDP

| virtual  |  custom         | Fields |
|----------|-----------------|---------------|
| signal-A | signal-udpports | source port : destination port |
| signal-B | signal-udplen   | length : checksum |


Complete Signal order for IPv6 on vanilla signals

`signal-white`, `signal-grey`, and `signal-black` are left unordered, as these are used by the Feathernet link layer header.

| signal |
|--------|
|signal-0|
|signal-1|
|signal-2|
|signal-3|
|signal-4|
|signal-5|
|signal-6|
|signal-7|
|signal-8|
|signal-9|
|signal-A|
|signal-B|
|signal-C|
|signal-D|
|signal-E|
|signal-F|
|signal-G|
|signal-H|
|signal-I|
|signal-J|
|signal-K|
|signal-L|
|signal-M|
|signal-N|
|signal-O|
|signal-P|
|signal-Q|
|signal-R|
|signal-S|
|signal-T|
|signal-U|
|signal-V|
|signal-W|
|signal-X|
|signal-Y|
|signal-Z|
|signal-red|
|signal-green|
|signal-blue|
|signal-yellow|
|signal-pink|
|signal-cyan|
|water|
|crude-oil|
|steam|
|heavy-oil|
|light-oil|
|petroleum-gas|
|sulfuric-acid|
|lubricant|
|wooden-chest|
|iron-chest|
|steel-chest|
|storage-tank|
|transport-belt|
|fast-transport-belt|
|express-transport-belt|
|underground-belt|
|fast-underground-belt|
|express-underground-belt|
|splitter|
|fast-splitter|
|express-splitter|
|burner-inserter|
|inserter|
|long-handed-inserter|
|fast-inserter|
|filter-inserter|
|stack-inserter|
|stack-filter-inserter|
|small-electric-pole|
|medium-electric-pole|
|big-electric-pole|
|substation|
|pipe|
|pipe-to-ground|
|pump|
|rail|
|train-stop|
|rail-signal|
|rail-chain-signal|
|locomotive|
|cargo-wagon|
|fluid-wagon|
|car|
|tank|
|logistic-robot|
|construction-robot|
|logistic-chest-active-provider|
|logistic-chest-passive-provider|
|logistic-chest-requester|
|logistic-chest-storage|
|roboport|
|small-lamp|
|red-wire|
|green-wire|
|arithmetic-combinator|
|decider-combinator|
|constant-combinator|
|power-switch|
|programmable-speaker|
|stone-brick|
|concrete|
|hazard-concrete|
|landfill|
|iron-axe|
|steel-axe|
|repair-pack|
|blueprint|
|deconstruction-planner|
|blueprint-book|
|boiler|
|steam-engine|
|steam-turbine|
|solar-panel|
|accumulator|
|nuclear-reactor|
|heat-exchanger|
|heat-pipe|
|burner-mining-drill|
|electric-mining-drill|
|offshore-pump|
|pumpjack|
|stone-furnace|
|steel-furnace|
|electric-furnace|
|assembling-machine-1|
|assembling-machine-2|
|assembling-machine-3|
|oil-refinery|
|chemical-plant|
|centrifuge|
|lab|
|beacon|
|speed-module|
|speed-module-2|
|speed-module-3|
|effectivity-module|
|effectivity-module-2|
|effectivity-module-3|
|productivity-module|
|productivity-module-2|
|productivity-module-3|
|raw-wood|
|coal|
|stone|
|iron-ore|
|copper-ore|
|uranium-ore|
|raw-fish|
|wood|
|iron-plate|
|copper-plate|
|solid-fuel|
|steel-plate|
|sulfur|
|plastic-bar|
|crude-oil-barrel|
|heavy-oil-barrel|
|light-oil-barrel|
|lubricant-barrel|
|petroleum-gas-barrel|
|sulfuric-acid-barrel|
|water-barrel|
|copper-cable|
|iron-stick|
|iron-gear-wheel|
|empty-barrel|
|electronic-circuit|
|advanced-circuit|
|processing-unit|
|engine-unit|
|electric-engine-unit|
|battery|
|explosives|
|flying-robot-frame|
|low-density-structure|
|rocket-fuel|
|rocket-control-unit|
|satellite|
|uranium-235|
|uranium-238|
|uranium-fuel-cell|
|used-up-uranium-fuel-cell|
|science-pack-1|
|science-pack-2|
|science-pack-3|
|military-science-pack|
|production-science-pack|
|high-tech-science-pack|
|space-science-pack|
|pistol|
|submachine-gun|
|shotgun|
|combat-shotgun|
|rocket-launcher|
|flamethrower|
|land-mine|
|firearm-magazine|
|piercing-rounds-magazine|
|uranium-rounds-magazine|
|shotgun-shell|
|piercing-shotgun-shell|
|cannon-shell|
|explosive-cannon-shell|
|uranium-cannon-shell|
|explosive-uranium-cannon-shell|
|rocket|
|explosive-rocket|
|atomic-bomb|
|flamethrower-ammo|
|grenade|
|cluster-grenade|
|poison-capsule|
|slowdown-capsule|
|defender-capsule|
|distractor-capsule|
|destroyer-capsule|
|discharge-defense-remote|
|light-armor|
|heavy-armor|
|modular-armor|
|power-armor|
|power-armor-mk2|
|power-armor-mk3|
|power-armor-mk4|
|solar-panel-equipment|
|fusion-reactor-equipment|
|energy-shield-equipment|
|energy-shield-mk2-equipment|
|battery-equipment|
|battery-mk2-equipment|
|personal-laser-defense-equipment|
|discharge-defense-equipment|
|exoskeleton-equipment|
|personal-roboport-equipment|
|personal-roboport-mk2-equipment|
|night-vision-equipment|
|stone-wall|
|gate|
|gun-turret|
|laser-turret|
|flamethrower-turret|
|radar|
|rocket-silo|