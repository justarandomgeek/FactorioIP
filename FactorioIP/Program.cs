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
using System.Net.WebSockets;
using System.Collections.Specialized;

namespace FactorioIP
{
    class Program
    {
        
        public static void Main(string[] args)
        {
            // set up a socket for GRE=47, listen on any address...
            Socket gresock = new Socket(SocketType.Raw, (ProtocolType)47);
            gresock.Bind(new IPEndPoint(IPAddress.Any, 0));
            gresock.Connect("10.42.2.1", 0);
            
            // buffer to put packets in...
            byte[] rcvbuf = new byte[1500];
            var sendbuf = new Queue<byte[]>();
            
            var clusterio = new WebClient();
            clusterio.Encoding = Encoding.UTF8;
            var baseuri = new UriBuilder("http", "localhost", 8080).Uri;
            
            var lastcheck = DateTimeOffset.Now.ToUniversalTime().ToUnixTimeMilliseconds();

            while (true)
            {
                // check for inbound packets to foward to clusterio
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
                                        var jsonpacket = packet_to_circuit(rcvbuf, ((v4Header.headLen + 1) * 4), v6inHeader.totalLen);

                                        //Console.WriteLine(jsonpacket);
                                        //clusterio.Headers.Add(HttpRequestHeader.ContentType, "application/json");
                                        //var result = clusterio.UploadString(new Uri(baseuri, "/api/setSignal"), "POST", jsonpacket);
                                        var result = clusterio.UploadValues(new Uri(baseuri, "/api/setSignal"), "POST", jsonpacket);
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

                if (lastcheck + 500 < DateTimeOffset.Now.ToUniversalTime().ToUnixTimeMilliseconds())
                {
                    //check for new clusterio packets and send them out...
                    Console.WriteLine($"Getting packets since {lastcheck}...");
                    clusterio.Headers.Add(HttpRequestHeader.ContentType, "application/x-www-form-urlencoded");
                    var t = clusterio.UploadString(new Uri(baseuri, "/api/readSignal"), "POST", $"since={lastcheck}");
                    Console.WriteLine(t);
                    lastcheck = DateTimeOffset.Now.ToUniversalTime().ToUnixTimeMilliseconds();
                    foreach (var packet in circuit_to_packet(t))
                        sendbuf.Enqueue(packet);
                    
                    
                    
                }

                if (sendbuf.Count > 0 & gresock.Poll(0, SelectMode.SelectWrite))
                {
                    GREHeader outhead = new GREHeader { flags_ver = 0, protocol = 0x86dd };
                    var payload = sendbuf.Dequeue();
                    var packet = new List<ArraySegment<byte>>{
                        new ArraySegment<byte>(outhead.ToBytes()),
                        new ArraySegment<byte>(payload)
                    };
                    gresock.Send(packet);
                }


                
            }
            
        }

        struct CircuitFramePacket
        {
            public UInt64 time;
            public List<CircuitFrameValue> frame;
            public string origin;
        }
        struct CircuitFrameValue
        {
            public string name;
            public string type;
            public Int32 count;
        }

        static Queue<byte[]> circuit_to_packet(string jsonlist)
        {
            var packets = new Queue<byte[]>();
            if (jsonlist != "[]")
            {
                var json = new JavaScriptSerializer();
                var frames = json.Deserialize<List<CircuitFramePacket>>(jsonlist);

                foreach (var frame in frames)
                {
                    // don't process my own reflection
                    if (frame.origin == "FactorioIP") continue;

                    var sigdict = frame.frame.ToDictionary(fkey => fkey.name, fval => fval.count);

                    //check for a Feathernet header tagged for IP traffic
                    if (sigdict.ContainsKey("signal-black") && sigdict["signal-black"]==1 &&
                        sigdict.ContainsKey("signal-white") && sigdict["signal-white"] == 1)
                    {
                        var size = signals.Count*4;
                        switch (sigdict["signal-0"] >> 28)
                        {
                            case 6:
                                size = ((UInt16)(sigdict["signal-1"]>>16)) + 40;
                                break;
                            case 4:
                                size = ((UInt16)(sigdict["signal-0"]));
                                break;
                            default:
                                break;
                        }


                        byte[] framepacket = new byte[size];
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

                        packets.Enqueue(framepacket);

                    }

                    
                }
            }

            return packets;
        }


        static NameValueCollection packet_to_circuit(byte[] buffer, int startAt, int size)
        {
            //var json = new JavaScriptSerializer();
            //var frame = new List<dynamic>();
            //
            //dynamic packet = new {
            //    time = DateTimeOffset.Now.ToUniversalTime().ToUnixTimeMilliseconds(),
            //    frame = frame
            //};

            var nvpPacket = new NameValueCollection();
            nvpPacket["time"] = DateTimeOffset.Now.ToUniversalTime().ToUnixTimeMilliseconds().ToString();
            nvpPacket["origin"] = "FactorioIP"; // clusterio ignores this, but preserves it for me. It makes it easy to skip my own reflection

            int i,j;
            for (i = startAt, j=0; i < startAt+size; i+=4, j++)
            {
                Int32 nextword = ((buffer[i] << 24) | (buffer[i + 1] << 16) | (buffer[i + 2] << 8) | (buffer[i + 3]));
                // clear tail bytes if last word...
                if ((startAt + size) - i < 4)
                {
                    nextword = (Int32)(nextword & (0xffffffff << ((4 - ((startAt + size) - i)) * 8)));
                }

                nvpPacket[$"frame[{j}][type]"] = j < 42 ? "virtual" : j < 50 ? "fluid" : "item";
                nvpPacket[$"frame[{j}][name]"] = signals[j];
                nvpPacket[$"frame[{j}][count]"] = nextword.ToString();
                

                //frame.Add(new {
                //    type = j < 42 ? "virtual" : j < 50 ? "fluid" : "item",
                //    name = signals[j],
                //    count = nextword,
                //});
            }
            //TODO: add feathernet header? or leave that to hardware?
            //return json.Serialize(packet);
            return nvpPacket;
        }

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
            "car",
            "tank",
            "logistic-robot",
            "construction-robot",
            "logistic-chest-active-provider",
            "logistic-chest-passive-provider",
            "logistic-chest-requester",
            "logistic-chest-storage",
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
            "sulfur",
            "plastic-bar",
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
            "battery",
            "explosives",
            "flying-robot-frame",
            "low-density-structure",
            "rocket-fuel",
            "rocket-control-unit",
            "satellite",
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
            "light-armor",
            "heavy-armor",
            "modular-armor",
            "power-armor",
            "power-armor-mk2",
            "power-armor-mk3",
            "power-armor-mk4",
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
            "radar",
            "rocket-silo",
        }; 
    }
}
