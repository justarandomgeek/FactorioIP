using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Net;
using System.Net.Sockets;
using System.Web.Script.Serialization;
using System.Net.Http;
using System.IO;
using System.Collections.Specialized;
using System.Net.WebSockets;
using System.Threading;

namespace FactorioIP
{
    class Program
    {
        struct TypeAndPacket
        {
            public UInt16 Type;
            public byte[] Data;
        }
        public static int uniqueID = new Random().Next();
        public static void Main(string[] args)
        {
            // set up a socket for GRE=47, listen on any address...
            Socket gresock = new Socket(SocketType.Raw, (ProtocolType)47);
            gresock.Bind(new IPEndPoint(IPAddress.Any, 0));
            gresock.Connect("10.42.2.1", 0);
            
            // buffer to put packets in...
            byte[] rcvbuf = new byte[1500];
            var sendbuf = new Queue<TypeAndPacket>();
            IAsyncResult ongoingsend = null;

            var clusterio = new SocketIOClient();
            clusterio.On("hello", t =>
            {
                Console.WriteLine("Clusterio Connected");
                clusterio.Emit("registerSlave", new { instanceID = uniqueID });
                clusterio.Emit("heartbeat");
            });
            clusterio.On("processCombinatorSignal", t =>
            {
                TypeAndPacket packet = circuit_to_packet(t);
                if (packet.Type != 0) sendbuf.Enqueue(packet);
            });

            clusterio.Connect("localhost", 8080);
            

            long nexthb = 0;

            while (true)
            {
                var now = DateTimeOffset.Now.ToUniversalTime().ToUnixTimeMilliseconds();
                // check for inbound packets to foward to clusterio

                if (now >= nexthb)
                {
                    clusterio.Emit("heartbeat");
                    nexthb = now + 10000;
                }

                if (gresock.Poll(0, SelectMode.SelectRead))
                {
                    gresock.Receive(rcvbuf);
                    switch (rcvbuf[0]>>4)
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
                                    if (v6inHeader.payloadLen + 40 <= signals.Count * 4)
                                    {
                                        var circpacket = packet_to_circuit(rcvbuf, ((v4Header.headLen + 1) * 4), v6inHeader.totalLen);
                                        clusterio.Emit("combinatorSignal", circpacket);
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
                
                if ((ongoingsend?.IsCompleted!=false) && sendbuf.Count > 0)
                {
                    
                    var payload = sendbuf.Dequeue();

                    GREHeader outhead = new GREHeader { flags_ver = 0, protocol = payload.Type };
                    
                    switch (payload.Type)
                    {
                        case 0x86dd:
                            var v6outHeader = IPv6Header.FromBytes(payload.Data, 0);
                            Console.WriteLine($"Type: {v6outHeader.nextHeader} Payload: {v6outHeader.payloadLen} From: {v6outHeader.source} To: {v6outHeader.dest}");
                            break;
                        case 0x0800:
                            var v4outHeader = IPv4Header.FromBytes(payload.Data, 0);
                            Console.WriteLine($"Type: {v4outHeader.protocol} Size: {v4outHeader.totalLen} From: {v4outHeader.source} To: {v4outHeader.dest}");
                            break;
                        case 0x88B5:
                            //Console.WriteLine($"FCP");
                            //TODO: move FCP prints form circuit_to_packet here with a proper header decode
                            break;
                        default:
                            break;
                    }
                    

                    var packet = new List<ArraySegment<byte>>{
                        new ArraySegment<byte>(outhead.ToBytes()),
                        new ArraySegment<byte>(payload.Data)
                    };
                    ongoingsend = gresock.BeginSend(packet,SocketFlags.None,null,null);
                }


                
            }
            
        }

        struct CircuitFramePacket
        {
            public Int64 time;
            public List<CircuitFrameValue> frame;
            public string origin;
        }
        struct CircuitFrameValue
        {
            public string name;
            public string type;
            public Int32 count;
        }

        static TypeAndPacket circuit_to_packet(dynamic circpacket)
        {
            var json = new JavaScriptSerializer();
            var frame = json.Deserialize<CircuitFramePacket>((string)json.Serialize(circpacket));
            byte[] framepacket = null;
            UInt16 type = 0;

            // don't process my own reflection
            if (frame.origin == "FactorioIP") return new TypeAndPacket { Type = type, Data = framepacket };

            var sigdict = frame.frame.ToDictionary(fkey => fkey.name, fval => fval.count);
            var size = signals.Count * 4;

            //check for a Feathernet header tagged for IP traffic
            if (sigdict.ContainsKey("signal-white") && sigdict["signal-white"] == 1)
            {
                switch (sigdict["signal-0"] >> 28)
                {
                    case 6:
                        size = ((UInt16)(sigdict["signal-1"]>>16)) + 40;
                        type = 0x86dd;
                        break;
                    case 4:
                        size = ((UInt16)(sigdict["signal-0"] & 0xffff));
                        type = 0x0800;
                        break;
                    default:
                        break;
                }
                
            }
            else if (sigdict.ContainsKey("signal-white") && sigdict["signal-white"] == 2)
            {
                
                switch (sigdict["signal-0"])
                {
                    case 1:
                        Console.WriteLine($"FCP Sol {sigdict["signal-1"]:x8}");
                        type = 0x88B5;
                        size = 8;
                        break;
                    case 2:
                        Console.WriteLine($"FCP Adv {sigdict["signal-1"]:x8}");
                        type = 0x88B5;
                        size = 8;
                        break;
                    default:
                        Console.WriteLine("Unknown FCP Message");
                        break;
                }

            }

            if (type != 0)
            {
                framepacket = new byte[size];
                for (int i = 0; i < size; i += 4)
                {
                    if (sigdict.ContainsKey(signals[i / 4]))
                    {

                        switch (size - i)
                        {
                            default:
                                framepacket[i + 3] = (byte)(sigdict[signals[i / 4]] >> 0);
                                goto case 3; // continue doens't work in a for loop...
                            case 3:
                                framepacket[i + 2] = (byte)(sigdict[signals[i / 4]] >> 8);
                                goto case 2;
                            case 2:
                                framepacket[i + 1] = (byte)(sigdict[signals[i / 4]] >> 16);
                                goto case 1;
                            case 1:
                                framepacket[i + 0] = (byte)(sigdict[signals[i / 4]] >> 24);
                                break;
                        }
                    }
                }
            }
            return new TypeAndPacket { Type = type, Data = framepacket };
        }

        
        static CircuitFramePacket packet_to_circuit(byte[] buffer, int startAt, int size)
        {
            var frame = new List<CircuitFrameValue>();
            var packet = new CircuitFramePacket
            {
                time = DateTimeOffset.Now.ToUniversalTime().ToUnixTimeMilliseconds(),
                frame = frame,
                origin = "FactorioIP" // clusterio ignores this, but preserves it for me. It makes it easy to skip my own reflection
            };

            int i,j;
            for (i = startAt, j=0; i < startAt+size; i+=4, j++)
            {
                Int32 nextword = ((buffer[i] << 24) | (buffer[i + 1] << 16) | (buffer[i + 2] << 8) | (buffer[i + 3]));
                // clear tail bytes if last word...
                if ((startAt + size) - i < 4)
                {
                    nextword = (Int32)(nextword & (0xffffffff << ((4 - ((startAt + size) - i)) * 8)));
                }

                frame.Add(new CircuitFrameValue
                {
                    type = (j < 42 || j > 249) ? "virtual" : j < 50 ? "fluid" : "item",
                    name = signals[j],
                    count = nextword,
                });
            }

            // add a world-id to be consistent with other clusterio traffic
            frame.Add(new CircuitFrameValue { type = "virtual", name = "signal-srcid", count = 1, });

            //add a feathernet header tagging this as IP traffic
            frame.Add(new CircuitFrameValue { type = "virtual", name = "signal-white", count = 1, });

            var head = IPv6Header.FromBytes(buffer, startAt);
            Int32 destaddr = head.dest.IsIPv6Multicast ? 0 : ((buffer[startAt+36] << 24) | (buffer[startAt + 37] << 16) | (buffer[startAt + 38] << 8) | (buffer[startAt + 39]));
            frame.Add(new CircuitFrameValue { type = "virtual", name = "signal-grey", count = destaddr, });
            return packet;
        }


        // all vanilla signals except grey/white/black, used by feathernet header, and NIC internals
        static List<string> signals = new List<string>{
            "signal-0",
            "signal-1",
            "signal-2",
            "signal-3",
            "signal-4",
            "signal-5",
            "signal-6",
            "signal-7",
            "signal-8",
            "signal-9",
            "signal-A",
            "signal-B",
            "signal-C",
            "signal-D",
            "signal-E",
            "signal-F",
            "signal-G",
            "signal-H",
            "signal-I",
            "signal-J",
            "signal-K",
            "signal-L",
            "signal-M",
            "signal-N",
            "signal-O",
            "signal-P",
            "signal-Q",
            "signal-R",
            "signal-S",
            "signal-T",
            "signal-U",
            "signal-V",
            "signal-W",
            "signal-X",
            "signal-Y",
            "signal-Z",
            "signal-red",
            "signal-green",
            "signal-blue",
            "signal-yellow",
            "signal-pink",
            "signal-cyan",

            "water",
            "crude-oil",
            "steam",
            "heavy-oil",
            "light-oil",
            "petroleum-gas",
            "sulfuric-acid",
            "lubricant",

            "wooden-chest",
            "iron-chest",
            "steel-chest",
            "storage-tank",
            "transport-belt",
            "fast-transport-belt",
            "express-transport-belt",
            "underground-belt",
            "fast-underground-belt",
            "express-underground-belt",
            "splitter",
            "fast-splitter",
            "express-splitter",
            "burner-inserter",
            "inserter",
            "long-handed-inserter",
            "fast-inserter",
            "filter-inserter",
            "stack-inserter",
            "stack-filter-inserter",
            "small-electric-pole",
            "medium-electric-pole",
            "big-electric-pole",
            "substation",
            "pipe",
            "pipe-to-ground",
            "pump",
            "rail",
            "train-stop",
            "rail-signal",
            "rail-chain-signal",
            "locomotive",
            "cargo-wagon",
            "fluid-wagon",
            "artillery-wagon",
            "car",
            "tank",
            "logistic-robot",
            "construction-robot",
            "logistic-chest-active-provider",
            "logistic-chest-passive-provider",
            "logistic-chest-storage",
            "logistic-chest-buffer",
            "logistic-chest-requester",
            "roboport",
            "small-lamp",
            "red-wire",
            "green-wire",
            "arithmetic-combinator",
            "decider-combinator",
            "constant-combinator",
            "power-switch",
            "programmable-speaker",
            "stone-brick",
            "concrete",
            "hazard-concrete",
            "landfill",
            "cliff-explosives",
            "iron-axe",
            "steel-axe",
            "repair-pack",
            "blueprint",
            "deconstruction-planner",
            "blueprint-book",
            "boiler",
            "steam-engine",
            "steam-turbine",
            "solar-panel",
            "accumulator",
            "nuclear-reactor",
            "heat-exchanger",
            "heat-pipe",
            "burner-mining-drill",
            "electric-mining-drill",
            "offshore-pump",
            "pumpjack",
            "stone-furnace",
            "steel-furnace",
            "electric-furnace",
            "assembling-machine-1",
            "assembling-machine-2",
            "assembling-machine-3",
            "oil-refinery",
            "chemical-plant",
            "centrifuge",
            "lab",
            "beacon",
            "speed-module",
            "speed-module-2",
            "speed-module-3",
            "effectivity-module",
            "effectivity-module-2",
            "effectivity-module-3",
            "productivity-module",
            "productivity-module-2",
            "productivity-module-3",
            "raw-wood",
            "coal",
            "stone",
            "iron-ore",
            "copper-ore",
            "uranium-ore",
            "raw-fish",
            "wood",
            "iron-plate",
            "copper-plate",
            "solid-fuel",
            "steel-plate",
            "plastic-bar",
            "sulfur",
            "battery",
            "explosives",
            "crude-oil-barrel",
            "heavy-oil-barrel",
            "light-oil-barrel",
            "lubricant-barrel",
            "petroleum-gas-barrel",
            "sulfuric-acid-barrel",
            "water-barrel",
            "copper-cable",
            "iron-stick",
            "iron-gear-wheel",
            "empty-barrel",
            "electronic-circuit",
            "advanced-circuit",
            "processing-unit",
            "engine-unit",
            "electric-engine-unit",
            "flying-robot-frame",
            "satellite",
            "rocket-control-unit",
            "low-density-structure",
            "rocket-fuel",
            "nuclear-fuel",
            "uranium-235",
            "uranium-238",
            "uranium-fuel-cell",
            "used-up-uranium-fuel-cell",
            "science-pack-1",
            "science-pack-2",
            "science-pack-3",
            "military-science-pack",
            "production-science-pack",
            "high-tech-science-pack",
            "space-science-pack",
            "pistol",
            "submachine-gun",
            "shotgun",
            "combat-shotgun",
            "rocket-launcher",
            "flamethrower",
            "land-mine",
            "firearm-magazine",
            "piercing-rounds-magazine",
            "uranium-rounds-magazine",
            "shotgun-shell",
            "piercing-shotgun-shell",
            "cannon-shell",
            "explosive-cannon-shell",
            "uranium-cannon-shell",
            "explosive-uranium-cannon-shell",
            "artillery-shell",
            "rocket",
            "explosive-rocket",
            "atomic-bomb",
            "flamethrower-ammo",
            "grenade",
            "cluster-grenade",
            "poison-capsule",
            "slowdown-capsule",
            "defender-capsule",
            "distractor-capsule",
            "destroyer-capsule",
            "discharge-defense-remote",
            "artillery-targeting-remote",
            "light-armor",
            "heavy-armor",
            "modular-armor",
            "power-armor",
            "power-armor-mk2",
            "solar-panel-equipment",
            "fusion-reactor-equipment",
            "energy-shield-equipment",
            "energy-shield-mk2-equipment",
            "battery-equipment",
            "battery-mk2-equipment",
            "personal-laser-defense-equipment",
            "discharge-defense-equipment",
            "exoskeleton-equipment",
            "personal-roboport-equipment",
            "personal-roboport-mk2-equipment",
            "night-vision-equipment",
            "stone-wall",
            "gate",
            "gun-turret",
            "laser-turret",
            "flamethrower-turret",
            "artillery-turret",
            "radar",
            "rocket-silo",
            
            "signal-250",
            "signal-251",
            "signal-252",
            "signal-253",
            "signal-254",
            "signal-255",
            "signal-256",
            "signal-257",
            "signal-258",
            "signal-259",

            "signal-260",
            "signal-261",
            "signal-262",
            "signal-263",
            "signal-264",
            "signal-265",
            "signal-266",
            "signal-267",
            "signal-268",
            "signal-269",

            "signal-270",
            "signal-271",
            "signal-272",
            "signal-273",
            "signal-274",
            "signal-275",
            "signal-276",
            "signal-277",
            "signal-278",
            "signal-279",

            "signal-280",
            "signal-281",
            "signal-282",
            "signal-283",
            "signal-284",
            "signal-285",
            "signal-286",
            "signal-287",
            "signal-288",
            "signal-289",

            "signal-290",
            "signal-291",
            "signal-292",
            "signal-293",
            "signal-294",
            "signal-295",
            "signal-296",
            "signal-297",
            "signal-298",
            "signal-299",

            "signal-300",
            "signal-301",
            "signal-302",
            "signal-303",
            "signal-304",
            "signal-305",
            "signal-306",
            "signal-307",
            "signal-308",
            "signal-309",

            "signal-310",
            "signal-311",
            "signal-312",
            "signal-313",
            "signal-314",
            "signal-315",
            "signal-316",
            "signal-317",
            "signal-318",
            "signal-319",
        }; 
    }
}
