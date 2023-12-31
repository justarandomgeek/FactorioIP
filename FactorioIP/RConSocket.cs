using CoreRCON;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FactorioIP
{
    class RConSocket : EndpointFrameSocket
    {

        readonly Queue<PackedFrame> sendbuf = new Queue<PackedFrame>();
        readonly string host;
        readonly UInt16 port;
        readonly string password;
        RCON rcon;
        bool rconAlive;

        public Action<UnpackedFrame> OnReceive { get; set; }
        public Action<RConSocket> OnConnect { get; set; }
        public Action<RConSocket> OnDisconnect { get; set; }

        public RConSocket(string host, UInt16 port, string password, Action<RConSocket> OnConnect = null, Action<RConSocket> OnDisconnect = null )
        {
            this.host = host;
            this.port = port;
            this.password = password;
            this.OnConnect = OnConnect;
            this.OnDisconnect = OnDisconnect;

            StartupTask();
        }


        async void StartupTask()
        {
            while (rcon == null)
            {
                try
                {
                    rcon = new RCON(host, port, password);
                }
                catch (System.AggregateException)
                {
                    Console.WriteLine($"{Name} failed to connect");
                }

                if (rcon != null)
                {
                    rcon.OnDisconnected += onDisconnected;

                    //rcon.SendCommandAsync("/RoutingReset").Wait();

                    ID = Int32.Parse(await rcon.SendCommandAsync("/RoutingGetID"));

                    string mapstr = await rcon.SendCommandAsync($"/RoutingGetMap");
                    mapstr = mapstr.TrimEnd('\0', '\n');
                    var split = mapstr.IndexOf(':');
                    var len = UInt32.Parse(mapstr[..split]);
                    mapstr = mapstr[(split + 1)..];

                    if (mapstr.Length != len)
                    {
                        throw new Exception("Map Truncated");
                    }
                    
                    using (var ms = new System.IO.MemoryStream(Convert.FromBase64String(mapstr)))
                    using (var gz = new System.IO.Compression.GZipStream(ms, System.IO.Compression.CompressionMode.Decompress))
                    using (var sr = new System.IO.StreamReader(gz))
                    {
                        var mapjson = sr.ReadToEnd();
                        var map = System.Text.Json.JsonSerializer.Deserialize<IEnumerable<Dictionary<string, string>>>(mapjson);
                        var siglist = map.Select(d => new SignalMap.SignalID { type = (string)d["type"], name = (string)d["name"] });
                        this.Map = new SignalMap(siglist);
                    }

                    rconAlive = true;
                    ReceiveTask();
                    SendTask();

                    OnConnect?.Invoke(this);

                }
                else
                {
                    // wait 30s
                    Task.Delay(30000).Wait();
                }
            }
        }

        void onDisconnected()
        {
            // declare it dead...
            rconAlive = false;
            OnDisconnect?.Invoke(this);

            rcon = null;
            StartupTask();
        }

        public void EnqueueSend(UnpackedFrame packet)
        {
            if (rconAlive)
            {
                var pframe = packet.Pack(Map);

                // don't bother sending an empty frame (usually no map, or no map overlap)...
                if (pframe.payload.Length == 2) return;

                sendbuf.Enqueue(pframe);
            }
        }

        public SignalMap Map { get; private set; }
        public VarInt ID { get; private set; }

        public string Name => $"RCON:{host}:{port}:{ID:X8}";
        public override string ToString() => Name;

        async void ReceiveTask()
        {
            while (rconAlive)
            {
                await Task.Delay(20);

                var packets = new ArraySegment<byte>(await rcon.SendCommandAsync(Encoding.UTF8.GetBytes("/RoutingTXBuff\0")));
                
                VarInt size;

                while (packets.Count > 2)
                {
                    (size, packets) = VarInt.Take(packets);

                    var packet = new ArraySegment<byte>(packets.Array, packets.Offset, size);

                    var packetframe = new PackedFrame(packet, Map).Unpack();
                    packetframe.origin = this;
                    OnReceive?.Invoke(packetframe);

                    packets = new ArraySegment<byte>(packets.Array, packets.Offset + size, packets.Count - size);
                }
            }

        }

        async void SendTask()
        {
            while (rconAlive)
            {
                if (sendbuf.Count > 0)
                {
                    var payload = sendbuf.Dequeue();

                    var bytes = Encoding.UTF8.GetBytes("/RoutingRX ").Concat(payload.Encode()).Concat(new byte[] { 0 }).ToArray();

                    try
                    {

                        await rcon.SendCommandAsync(bytes);
                    }
                    catch (System.Net.Sockets.SocketException)
                    {
                        onDisconnected();
                        //throw;
                    }
                }
                else
                {
                    //TODO: better way to wait for new packets?
                    await Task.Delay(1);
                } 
            }
        }

        public bool CanRoute(VarInt dst)
        {
            return rconAlive && dst == ID;
        }
    }
}
