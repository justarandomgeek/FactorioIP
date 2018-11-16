using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Runtime.Serialization.Formatters.Binary;
using System.IO;

namespace FactorioIP
{
    /*
     *   Client             Server
     *   [Connect] ------->
     *   Map  ------------>
     *   Peers <----------> Peers
     *   Frames <---------> Frames
     *   
     */

    class TCPFrameSocketListener
    {
        FrameRouter router;
        TcpListener listener;

        public TCPFrameSocketListener(UInt16 localport, FrameRouter router)
        {
            this.router = router;
            listener = new TcpListener(IPAddress.Any, localport);
            listener.Start();

            ListenTask();
        }

        async void ListenTask()
        {
            while (true)
            {
                var client = await listener.AcceptTcpClientAsync();

                new TCPFrameSocket(client, router);
            }
        }
    }

    class TCPFrameSocket : RoutingFrameSocket
    {
        // TCP transport for routing between instances.
        
        enum TCPState
        {
            Connected,     // fresh socket, just connected...
            WaitingForMap, // server waiting for map
            SendingMap,    // client sending map
            Ready,         // ready to exchange peers and frames
        }

        enum TCPMessageType : byte
        {
            PeerAnnounce,   // followed by a List<UInt32> peers (all current peers)
            Map,            // followed by List<(string,string)> map entries
            MapUpdate,      // followed by List<(string,string)> map entries
            Frame,          // followed by a BinaryFrame
        }

        [Serializable]
        struct BinaryFrame
        {
            public UInt32 dstid;
            public UInt32 srcid;
            public UInt32[] payload;
            // implied Map = TCP socket's map. New signals are added at the end of the map during a session, so any buffered frames need not change.
        }

        FrameRouter router;

        bool isServer;
        TcpClient tcp;
        NetworkStream stream;
        BinaryFormatter formatter = new BinaryFormatter();
        TCPState state;
        
        public string Name => $"TCP:{tcp.Client.RemoteEndPoint}";
        public override string ToString() => Name;

        // when created from a Listener...
        public TCPFrameSocket(TcpClient tcpClient, FrameRouter router)
        {
            isServer = true;
            this.router = router;
            tcp = tcpClient;
            stream = tcp.GetStream();
            State = TCPState.Connected;

            router.Register(this);

            State = TCPState.WaitingForMap;

            ReceiveTask();

            Console.WriteLine($"New TCP Socket From Listener: {Name}");
            //will send peers after receiving map and transitioning to Ready

        }

        // when created directly, as a client...
        public TCPFrameSocket(string peerhost, UInt16 peerport, FrameRouter router)
        {
            isServer = false;
            this.router = router;
            tcp = new TcpClient(peerhost, peerport);
            stream = tcp.GetStream();
            State = TCPState.Connected;

            this.Map = router.BuildCompositeMap();
            State = TCPState.SendingMap;

            router.Register(this);
            ReceiveTask();

            Console.WriteLine($"New TCP Socket: {Name}");
        }


        async void ReceiveTask()
        {
            while (true)
            {
                if (stream.DataAvailable)
                {
                    TCPMessageType type = (TCPMessageType)stream.ReadByte();
                    switch (type)
                    {
                        case TCPMessageType.Map:
                            if (isServer && State == TCPState.WaitingForMap)
                            {
                                var newmap = (List< SignalMap.SignalID>)formatter.Deserialize(stream);
                                Map = new SignalMap(newmap);
                                State = TCPState.Ready;
                                Console.WriteLine($"{Name}: Recieved Map with {Map.Count} signals");
                            }
                            else
                                throw new InvalidOperationException();
                            break;
                        case TCPMessageType.MapUpdate:
                            if (isServer && State == TCPState.Ready)
                            {
                                var newmap = (List<SignalMap.SignalID>)formatter.Deserialize(stream);
                                var oldcount = Map.Count;
                                Map.AddRange(newmap);
                                Console.WriteLine($"{Name}: Recieved Map Update with {newmap.Count} signals. Map {oldcount} -> {Map.Count} signals.");
                                // map update...
                            }
                            else
                                throw new InvalidOperationException();
                            break;


                        case TCPMessageType.PeerAnnounce:
                            if (State == TCPState.Ready)
                            {
                                // read peers into remotePeers
                                var newpeers = (List<VarInt>)formatter.Deserialize(stream);
                                remotePeers = newpeers.ToList();
                                Console.WriteLine($"{Name}: Recieved Peers {remotePeers.Print()} ");
                            }
                            else
                                throw new InvalidOperationException();
                            break;

                        case TCPMessageType.Frame:
                            if (State == TCPState.Ready)
                            {
                                var bframe = (BinaryFrame)formatter.Deserialize(stream);
                                var pframe = new PackedFrame(
                                    bframe.dstid, bframe.srcid,
                                    bframe.payload.Select(u => (VarInt)u),
                                    Map);
                                var frame = pframe.Unpack();

                                Console.WriteLine($"{Name}: Recieved Frame of {frame.signals.Length} signals in {bframe.payload.Length} VarInts");

                                frame.origin = this;
                                OnReceive?.Invoke(frame);
                            }
                            else
                                throw new InvalidOperationException();
                            break;
                        default:
                            throw new InvalidOperationException();
                    }
                }
                else
                {
                    await Task.Delay(10);
                }
            }
        }

        public Action<UnpackedFrame> OnReceive { get; set; }

        public SignalMap Map { get; private set; }

        List<VarInt> remotePeers = new List<VarInt>();
        public IEnumerable<VarInt> RoutablePeers => remotePeers.AsReadOnly();

        private TCPState State
        {
            get => state;
            set
            {
                var oldstate = state;
                state = value;
                if (state != oldstate)
                {
                    switch (state)
                    {
                        case TCPState.Connected:
                            Console.WriteLine($"{Name}: Connected");
                            // wait...
                            break;
                        case TCPState.WaitingForMap:
                            Console.WriteLine($"{Name}: WaitingForMap");
                            // wait...
                            break;
                        case TCPState.SendingMap:
                            // send initial map now
                            Console.WriteLine($"{Name}: SendingMap {Map.Count} signals");
                            using (var ms = new MemoryStream())
                            {
                                ms.WriteByte((byte)TCPMessageType.Map);
                                formatter.Serialize(ms, Map.All.ToList());

                                ms.Seek(0, SeekOrigin.Begin);
                                ms.CopyTo(stream);
                            }
                            State = TCPState.Ready;
                            break;
                        case TCPState.Ready:
                            Console.WriteLine($"{Name}: Ready");

                            if (isServer)
                            {
                                this.AnnouncePeers(router.LocalPeers);
                            }
                            
                            // send peers, frames, mapupdates as they happen
                            break;
                        default:
                            break;
                    }
                }
            }
        }

        public bool CanRoute(VarInt dst)
        {
            return State == TCPState.Ready && remotePeers.Contains(dst);
        }

        public void EnqueueSend(UnpackedFrame frame)
        {
            if (State != TCPState.Ready) return;

            var pframe = frame.Pack(Map);

            BinaryFrame bframe = new BinaryFrame();
            bframe.dstid = pframe.dstid;
            bframe.srcid = pframe.srcid;
            bframe.payload = pframe.payload.Select(v => (UInt32)v).ToArray();

            using (var ms = new MemoryStream())
            {
                stream.WriteByte((byte)TCPMessageType.Frame);
                formatter.Serialize(stream, bframe);

                Console.WriteLine($"{Name}: Sending Frame of {frame.signals.Length} signals in {bframe.payload.Length} VarInts");

                ms.Seek(0, SeekOrigin.Begin);
                ms.CopyTo(stream);
            }
        }

        public void AnnouncePeers(IEnumerable<VarInt> peers)
        {
            if (State != TCPState.Ready) return;

            // announce local peers to the remote end of transport link...
            using (var ms = new MemoryStream())
            {
                stream.WriteByte((byte)TCPMessageType.PeerAnnounce);
                formatter.Serialize(stream, peers.ToList());

                Console.WriteLine($"{Name}: Sending Peers {peers.Print()}");

                ms.Seek(0, SeekOrigin.Begin);
                ms.CopyTo(stream);
            }

            if (!isServer)
            {
                // check for any new signals, and if found add them to end of map and send a MapUpdate with the PeerAnnounce
                var newsigs = router.BuildCompositeMap().All.Where(s => !Map.All.Contains(s)).ToList();
                if (newsigs.Count > 0)
                {
                    using (var ms = new MemoryStream())
                    {
                        stream.WriteByte((byte)TCPMessageType.MapUpdate);
                        formatter.Serialize(stream, newsigs);

                        Console.WriteLine($"{Name}: Sending MapUpdate {newsigs.Count}");

                        ms.Seek(0, SeekOrigin.Begin);
                        ms.CopyTo(stream);
                    }
                    Map.AddRange(newsigs);
                }

            }
        }
    }
}
