using CoreRCON;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

namespace FactorioIP
{
    class RConSocket : EndpointFrameSocket
    {

        Queue<PackedFrame> sendbuf = new Queue<PackedFrame>();
        string host;
        UInt16 port;
        string password;
        RCON rcon;
        bool rconAlive;

        public Action<UnpackedFrame> OnReceive { get; set; }

        public RConSocket(string host, UInt16 port, string password, Action<UnpackedFrame> OnReceive = null)
        {
            this.host = host;
            this.port = port;
            this.password = password;
            this.OnReceive = OnReceive;
            
            // set up an RCON connection
            rcon = new RCON(host, port, password);

            StartupTask();

            // wait for ID and map to be fetched, so it gets announced properly...
            while(Map == null) { Task.Delay(10); }

        }



        async void StartupTask()
        {

            //rcon.SendCommandAsync("/RoutingReset").Wait();

            ID = Int32.Parse(await rcon.SendCommandAsync("/RoutingGetID"));


            var mapparts = new List<string>();

            var json = new JavaScriptSerializer();
            var i = 1;
            string mapstr;
            do
            {
                mapstr = await rcon.SendCommandAsync($"/RoutingGetMap {i}");
                mapstr = mapstr.TrimEnd('\0', '\n');
                mapparts.Add(mapstr);
                i++;

            } while (mapstr.Length >= 3999);

            mapstr = string.Concat(mapparts);

            using (var ms = new System.IO.MemoryStream(Convert.FromBase64String(mapstr)))
            using (var gz = new System.IO.Compression.GZipStream(ms, System.IO.Compression.CompressionMode.Decompress))
            using (var sr = new System.IO.StreamReader(gz))
            {
                var mapjson = sr.ReadToEnd();
                var map = json.Deserialize<IEnumerable<Dictionary<string, string>>>(mapjson);
                var siglist = map.Select(d => new SignalMap.SignalID { type = (string)d["type"], name = (string)d["name"] });
                this.Map = new SignalMap(siglist);
            }

            rconAlive = true;
            ReceiveTask();
            SendTask();
        }

        void onDisconnected()
        {
            // declare it dead...
            rconAlive = false;

            // wait 30s
            Task.Delay(30000).Wait();

            // reconnect...
            rcon = new RCON(host, port, password);

            StartupTask();

        }

        public void EnqueueSend(UnpackedFrame packet)
        {
            if (rconAlive)
            {
                sendbuf.Enqueue(packet.Pack(Map));
            }
        }

        public SignalMap Map { get; private set; }
        public VarInt ID { get; private set; }

        public string Name => $"RCON:{host};{port};{ID:X8}";
        public override string ToString() => Name;

        async void ReceiveTask()
        {
            while (rconAlive)
            {
                await Task.Delay(20);

                IEnumerable<byte> packets = await rcon.SendCommandAsync(Encoding.UTF8.GetBytes("/RoutingTXBuff\0"));
                VarInt size;

                while (packets.Count() > 2)
                {
                    (size, packets) = VarInt.Take(packets);

                    var packet = new PackedFrame(packets.Take(size), Map).Unpack();
                    packet.origin = this;
                    OnReceive?.Invoke(packet);

                    packets = packets.Skip(size);
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

                    await rcon.SendCommandAsync(bytes);
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
