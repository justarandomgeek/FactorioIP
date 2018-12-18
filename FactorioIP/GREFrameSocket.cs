using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace FactorioIP
{

    class GREFrameSocket: EndpointFrameSocket
    {

        GRESocket gre;

        public Action<UnpackedFrame> OnReceive { get; set ; }

        // TODO: more maps as signals change with version? How to support multiple maps here? Or just have to specify a common set for everyone?
        public SignalMap Map => Feathernet_0_16;

        // TODO: use remote IPv4 of tunnel? or 00005efe for ISATAP? or something more unique? probably only one GRE tunnel per net...
        public VarInt ID => 0xfffffffe;

        public string Name => gre.Name;
        public override string ToString() => Name;

        public GREFrameSocket(string host, Action<UnpackedFrame> OnReceive = null)
        {
            gre = new GRESocket(host, ReceivedBytes);

            
            this.OnReceive = OnReceive;
        }
        
        void ReceivedBytes(byte[] rcvbuf)
        {
            // convert to signals and OnRecieve()
            switch (rcvbuf[0] >> 4)
            {
                case 4:
                    var v4Header = IPv4Header.FromBytes(rcvbuf, 0);
                    if (v4Header.protocol != 47) break; // only GRE... this should be handled by socket, but just to be sure...
                    if (v4Header.headLen != 5) break; // don't currently handle any options
                    var GRE4Header = GREHeader.FromBytes(rcvbuf, (v4Header.headLen * 4));
                    if (GRE4Header.flags_ver != 0) break; // don't support any GRE flags, version is always 0

                    // convert inner to json for clusterio and submit... for now we only have v6 inner
                    switch (GRE4Header.protocol)
                    {
                        case 0x86dd:
                            var v6inHeader = IPv6Header.FromBytes(rcvbuf, ((v4Header.headLen + 1) * 4));
                            Console.WriteLine($"Type: {v6inHeader.nextHeader} Payload: {v6inHeader.payloadLen} From: {v6inHeader.source} To: {v6inHeader.dest}");
                            if (v6inHeader.payloadLen + 40 <= ((Feathernet_0_16.Count - 2)  * 4))
                            {
                                if (v6inHeader.nextHeader == 44)
                                {
                                    Console.WriteLine("Fragmented packet dropped");
                                }
                                else
                                {
                                    var circpacket = packet_to_circuit(rcvbuf, ((v4Header.headLen + 1) * 4), v6inHeader.totalLen).Unpack();
                                    circpacket.origin = this;
                                    OnReceive?.Invoke(circpacket);
                                }
                            }
                            else
                            {
                                Console.WriteLine("Too large");
                            }


                            break;
                        default:
                            break;
                    }

                    break;
                case 6:
                    var v6Header = IPv6Header.FromBytes(rcvbuf, 0);
                    var GRE6Header = GREHeader.FromBytes(rcvbuf, 40);

                    break;
                default:
                    break;
            }
        }

        PackedFrame packet_to_circuit(byte[] buffer, int startAt, int size)
        {
            var frame = new List<VarInt>();
            frame.Add(1); // firstsignal = 1 we start at the beginning of the map...
            frame.Add(((size+3) / 4) + 2 ); // sigcount = enough signals to hold all the bytes plus two for feathernet header...

            frame.Add(0); // grey = broadcast / placeholder for feathernet dest
            frame.Add(1); // white = 1 to mark feathernet map

            int i;
            for (i = startAt; i < startAt+size; i+=4)
            {
                Int32 nextword = ((buffer[i] << 24) | (buffer[i + 1] << 16) | (buffer[i + 2] << 8) | (buffer[i + 3]));
                // clear tail bytes if last word...
                if ((startAt + size) - i < 4)
                {
                    nextword = (Int32)(nextword & (0xffffffff << ((4 - ((startAt + size) - i)) * 8)));
                }

                frame.Add(nextword);
            }

            // add a world-id to be consistent with other clusterio traffic
            VarInt srcid = ID;


            
            var head = IPv6Header.FromBytes(buffer, startAt);
            var ipdest = head.dest;
            VarInt dstid, featherdst;
            if (ipdest.IsIPv6Multicast)
            {
                dstid = 0xffffffff;
                featherdst = 0;
            }
            else
            {
                var ipdestbytes = ipdest.GetAddressBytes();
                dstid = ((ipdestbytes[8] << 24) | (ipdestbytes[9] << 16) | (ipdestbytes[10] << 8) | (ipdestbytes[11]));
                featherdst = ((ipdestbytes[12] << 24) | (ipdestbytes[13] << 16) | (ipdestbytes[14] << 8) | (ipdestbytes[15]));

            }

            frame[2] = featherdst;

            return new PackedFrame(dstid, srcid, frame, Feathernet_0_16);
        }

        public void EnqueueSend(UnpackedFrame frame)
        {
            // format and hand to gre...
            UInt16 type = 0;
            var size = frame.signals.Count() * 4;

            var sigwhite = frame.signals.FirstOrDefault(cfv => cfv.name == "signal-white").count;
            var sig0 = frame.signals.FirstOrDefault(cfv => cfv.name == "signal-0").count;
            var sig1 = frame.signals.FirstOrDefault(cfv => cfv.name == "signal-1").count;
            switch ((UInt32)sigwhite)
            {
                case 1:
                    switch (sig0 >> 28)
                    {
                        case 6:
                            size = ((UInt16)(sig1 >> 16)) + 40;
                            type = 0x86dd;
                            break;
                        case 4:
                            size = ((UInt16)(sig0 & 0xffff));
                            type = 0x0800;
                            break;
                        default:
                            break;
                    }
                    break;
                case 2:
                    switch ((UInt32)sig0)
                    {
                        case 1:
                            Console.WriteLine($"FCP Sol {sig1:x8} {frame.srcid:x8}=>{frame.dstid:x8}");
                            type = 0x88B5;
                            size = 8;
                            break;
                        case 2:
                            Console.WriteLine($"FCP Adv {sig1:x8} {frame.srcid:x8}=>{frame.dstid:x8}");
                            type = 0x88B5;
                            size = 8;
                            break;
                        default:
                            Console.WriteLine($"Unknown FCP Message {sig0:x8} {sig1:x8} {frame.srcid:x8}=>{frame.dstid:x8}");
                            break;
                    }
                    break;
            }

            if (type != 0)
            {
                var pframe = frame.PackWithZeros(Feathernet_0_16);
                if (size % 4 != 0) size += 4 - (size % 4);
                var bytes = new byte[size];
                if (size <= 4 * (pframe.payload.Length - 4))
                {
                    for (int i = 0; i < size; i += 4)
                    {
                        UInt32 signal = pframe.payload[(i / 4) + 4];
                        bytes[i + 3] = (byte)(signal >> 0);
                        bytes[i + 2] = (byte)(signal >> 8);
                        bytes[i + 1] = (byte)(signal >> 16);
                        bytes[i + 0] = (byte)(signal >> 24);
                    }

                    gre.EnqueueSend(new TypeAndPacket { Type = type, Data = bytes });
                }
                else
                {
                    Console.WriteLine($"GRE Size Mismatch type=0x{type:x4} size={size}, signals={pframe.payload.Length}");
                }
            }
            else
            {
                Console.WriteLine($"Unrecognized GRE packet type=0x{type:x4} size={size}, signals={frame.signals.Count()}");
            }
        }

        
        public bool CanRoute(VarInt dst)
        {
            return dst == ID;
        }


        public static SignalMap Feathernet_0_16 = new SignalMap(new SignalMap.SignalID[] {
                    ("virtual","signal-grey"),
                    ("virtual","signal-white"),

                    ("virtual","signal-0"),
                    ("virtual","signal-1"),
                    ("virtual","signal-2"),
                    ("virtual","signal-3"),
                    ("virtual","signal-4"),
                    ("virtual","signal-5"),
                    ("virtual","signal-6"),
                    ("virtual","signal-7"),
                    ("virtual","signal-8"),
                    ("virtual","signal-9"),
                    ("virtual","signal-A"),
                    ("virtual","signal-B"),
                    ("virtual","signal-C"),
                    ("virtual","signal-D"),
                    ("virtual","signal-E"),
                    ("virtual","signal-F"),
                    ("virtual","signal-G"),
                    ("virtual","signal-H"),
                    ("virtual","signal-I"),
                    ("virtual","signal-J"),
                    ("virtual","signal-K"),
                    ("virtual","signal-L"),
                    ("virtual","signal-M"),
                    ("virtual","signal-N"),
                    ("virtual","signal-O"),
                    ("virtual","signal-P"),
                    ("virtual","signal-Q"),
                    ("virtual","signal-R"),
                    ("virtual","signal-S"),
                    ("virtual","signal-T"),
                    ("virtual","signal-U"),
                    ("virtual","signal-V"),
                    ("virtual","signal-W"),
                    ("virtual","signal-X"),
                    ("virtual","signal-Y"),
                    ("virtual","signal-Z"),
                    ("virtual","signal-red"),
                    ("virtual","signal-green"),
                    ("virtual","signal-blue" ),
                    ("virtual","signal-yellow" ),
                    ("virtual","signal-pink" ),
                    ("virtual","signal-cyan" ),

                    ("fluid","water"),
                    ("fluid","crude-oil"),
                    ("fluid","steam"),
                    ("fluid","heavy-oil"),
                    ("fluid","light-oil"),
                    ("fluid","petroleum-gas"),
                    ("fluid","sulfuric-acid"),
                    ("fluid","lubricant"),

                    ("item","wooden-chest"),
                    ("item","iron-chest"),
                    ("item","steel-chest"),
                    ("item","storage-tank"),
                    ("item","transport-belt"),
                    ("item","fast-transport-belt"),
                    ("item","express-transport-belt"),
                    ("item","underground-belt"),
                    ("item","fast-underground-belt"),
                    ("item","express-underground-belt"),
                    ("item","splitter"),
                    ("item","fast-splitter"),
                    ("item","express-splitter"),
                    ("item","burner-inserter"),
                    ("item","inserter"),
                    ("item","long-handed-inserter"),
                    ("item","fast-inserter"),
                    ("item","filter-inserter"),
                    ("item","stack-inserter"),
                    ("item","stack-filter-inserter"),
                    ("item","small-electric-pole"),
                    ("item","medium-electric-pole"),
                    ("item","big-electric-pole"),
                    ("item","substation"),
                    ("item","pipe"),
                    ("item","pipe-to-ground"),
                    ("item","pump"),
                    ("item","rail"),
                    ("item","train-stop"),
                    ("item","rail-signal"),
                    ("item","rail-chain-signal"),
                    ("item","locomotive"),
                    ("item","cargo-wagon"),
                    ("item","fluid-wagon"),
                    ("item","artillery-wagon"),
                    ("item","car"),
                    ("item","tank"),
                    ("item","logistic-robot"),
                    ("item","construction-robot"),
                    ("item","logistic-chest-active-provider"),
                    ("item","logistic-chest-passive-provider"),
                    ("item","logistic-chest-storage"),
                    ("item","logistic-chest-buffer"),
                    ("item","logistic-chest-requester"),
                    ("item","roboport"),
                    ("item","small-lamp"),
                    ("item","red-wire"),
                    ("item","green-wire"),
                    ("item","arithmetic-combinator"),
                    ("item","decider-combinator"),
                    ("item","constant-combinator"),
                    ("item","power-switch"),
                    ("item","programmable-speaker"),
                    ("item","stone-brick"),
                    ("item","concrete"),
                    ("item","hazard-concrete"),
                    ("item","landfill"),
                    ("item","cliff-explosives"),
                    ("item","iron-axe"),
                    ("item","steel-axe"),
                    ("item","repair-pack"),
                    ("item","blueprint"),
                    ("item","deconstruction-planner"),
                    ("item","blueprint-book"),
                    ("item","boiler"),
                    ("item","steam-engine"),
                    ("item","steam-turbine"),
                    ("item","solar-panel"),
                    ("item","accumulator"),
                    ("item","nuclear-reactor"),
                    ("item","heat-exchanger"),
                    ("item","heat-pipe"),
                    ("item","burner-mining-drill"),
                    ("item","electric-mining-drill"),
                    ("item","offshore-pump"),
                    ("item","pumpjack"),
                    ("item","stone-furnace"),
                    ("item","steel-furnace"),
                    ("item","electric-furnace"),
                    ("item","assembling-machine-1"),
                    ("item","assembling-machine-2"),
                    ("item","assembling-machine-3"),
                    ("item","oil-refinery"),
                    ("item","chemical-plant"),
                    ("item","centrifuge"),
                    ("item","lab"),
                    ("item","beacon"),
                    ("item","speed-module"),
                    ("item","speed-module-2"),
                    ("item","speed-module-3"),
                    ("item","effectivity-module"),
                    ("item","effectivity-module-2"),
                    ("item","effectivity-module-3"),
                    ("item","productivity-module"),
                    ("item","productivity-module-2"),
                    ("item","productivity-module-3"),
                    ("item","raw-wood"),
                    ("item","coal"),
                    ("item","stone"),
                    ("item","iron-ore"),
                    ("item","copper-ore"),
                    ("item","uranium-ore"),
                    ("item","raw-fish"),
                    ("item","wood"),
                    ("item","iron-plate"),
                    ("item","copper-plate"),
                    ("item","solid-fuel"),
                    ("item","steel-plate"),
                    ("item","plastic-bar"),
                    ("item","sulfur"),
                    ("item","battery"),
                    ("item","explosives"),
                    ("item","crude-oil-barrel"),
                    ("item","heavy-oil-barrel"),
                    ("item","light-oil-barrel"),
                    ("item","lubricant-barrel"),
                    ("item","petroleum-gas-barrel"),
                    ("item","sulfuric-acid-barrel"),
                    ("item","water-barrel"),
                    ("item","copper-cable"),
                    ("item","iron-stick"),
                    ("item","iron-gear-wheel"),
                    ("item","empty-barrel"),
                    ("item","electronic-circuit"),
                    ("item","advanced-circuit"),
                    ("item","processing-unit"),
                    ("item","engine-unit"),
                    ("item","electric-engine-unit"),
                    ("item","flying-robot-frame"),
                    ("item","satellite"),
                    ("item","rocket-control-unit"),
                    ("item","low-density-structure"),
                    ("item","rocket-fuel"),
                    ("item","nuclear-fuel"),
                    ("item","uranium-235"),
                    ("item","uranium-238"),
                    ("item","uranium-fuel-cell"),
                    ("item","used-up-uranium-fuel-cell"),
                    ("item","science-pack-1"),
                    ("item","science-pack-2"),
                    ("item","science-pack-3"),
                    ("item","military-science-pack"),
                    ("item","production-science-pack"),
                    ("item","high-tech-science-pack"),
                    ("item","space-science-pack"),
                    ("item","pistol"),
                    ("item","submachine-gun"),
                    ("item","shotgun"),
                    ("item","combat-shotgun"),
                    ("item","rocket-launcher"),
                    ("item","flamethrower"),
                    ("item","land-mine"),
                    ("item","firearm-magazine"),
                    ("item","piercing-rounds-magazine"),
                    ("item","uranium-rounds-magazine"),
                    ("item","shotgun-shell"),
                    ("item","piercing-shotgun-shell"),
                    ("item","cannon-shell"),
                    ("item","explosive-cannon-shell"),
                    ("item","uranium-cannon-shell"),
                    ("item","explosive-uranium-cannon-shell"),
                    ("item","artillery-shell"),
                    ("item","rocket"),
                    ("item","explosive-rocket"),
                    ("item","atomic-bomb"),
                    ("item","flamethrower-ammo"),
                    ("item","grenade"),
                    ("item","cluster-grenade"),
                    ("item","poison-capsule"),
                    ("item","slowdown-capsule"),
                    ("item","defender-capsule"),
                    ("item","distractor-capsule"),
                    ("item","destroyer-capsule"),
                    ("item","discharge-defense-remote"),
                    ("item","artillery-targeting-remote"),
                    ("item","light-armor"),
                    ("item","heavy-armor"),
                    ("item","modular-armor"),
                    ("item","power-armor"),
                    ("item","power-armor-mk2"),
                    ("item","solar-panel-equipment"),
                    ("item","fusion-reactor-equipment"),
                    ("item","energy-shield-equipment"),
                    ("item","energy-shield-mk2-equipment"),
                    ("item","battery-equipment"),
                    ("item","battery-mk2-equipment"),
                    ("item","personal-laser-defense-equipment"),
                    ("item","discharge-defense-equipment"),
                    ("item","exoskeleton-equipment"),
                    ("item","personal-roboport-equipment"),
                    ("item","personal-roboport-mk2-equipment"),
                    ("item","night-vision-equipment"),
                    ("item","stone-wall"),
                    ("item","gate"),
                    ("item","gun-turret"),
                    ("item","laser-turret"),
                    ("item","flamethrower-turret"),
                    ("item","artillery-turret"),
                    ("item","radar"),
                    ("item","rocket-silo"),

                    ("virtual","signal-250"),
                    ("virtual","signal-251"),
                    ("virtual","signal-252"),
                    ("virtual","signal-253"),
                    ("virtual","signal-254"),
                    ("virtual","signal-255"),
                    ("virtual","signal-256"),
                    ("virtual","signal-257"),
                    ("virtual","signal-258"),
                    ("virtual","signal-259"),
                    ("virtual","signal-260"),
                    ("virtual","signal-261"),
                    ("virtual","signal-262"),
                    ("virtual","signal-263"),
                    ("virtual","signal-264"),
                    ("virtual","signal-265"),
                    ("virtual","signal-266"),
                    ("virtual","signal-267"),
                    ("virtual","signal-268"),
                    ("virtual","signal-269"),
                    ("virtual","signal-270"),
                    ("virtual","signal-271"),
                    ("virtual","signal-272"),
                    ("virtual","signal-273"),
                    ("virtual","signal-274"),
                    ("virtual","signal-275"),
                    ("virtual","signal-276"),
                    ("virtual","signal-277"),
                    ("virtual","signal-278"),
                    ("virtual","signal-279"),
                    ("virtual","signal-280"),
                    ("virtual","signal-281"),
                    ("virtual","signal-282"),
                    ("virtual","signal-283"),
                    ("virtual","signal-284"),
                    ("virtual","signal-285"),
                    ("virtual","signal-286"),
                    ("virtual","signal-287"),
                    ("virtual","signal-288"),
                    ("virtual","signal-289"),
                    ("virtual","signal-290"),
                    ("virtual","signal-291"),
                    ("virtual","signal-292"),
                    ("virtual","signal-293"),
                    ("virtual","signal-294"),
                    ("virtual","signal-295"),
                    ("virtual","signal-296"),
                    ("virtual","signal-297"),
                    ("virtual","signal-298"),
                    ("virtual","signal-299"),
                    ("virtual","signal-300"),
                    ("virtual","signal-301"),
                    ("virtual","signal-302"),
                    ("virtual","signal-303"),
                    ("virtual","signal-304"),
                    ("virtual","signal-305"),
                    ("virtual","signal-306"),
                    ("virtual","signal-307"),
                    ("virtual","signal-308"),
                    ("virtual","signal-309"),
                    ("virtual","signal-310"),
                    ("virtual","signal-311"),
                    ("virtual","signal-312"),
                    ("virtual","signal-313"),
                    ("virtual","signal-314"),
                    ("virtual","signal-315"),
                    ("virtual","signal-316"),
                    ("virtual","signal-317"),
                    ("virtual","signal-318"),
                    ("virtual","signal-319"),
                }
        );
    }
}
