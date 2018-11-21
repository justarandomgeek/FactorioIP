using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FactorioIP
{
    class FrameRouter
    {
        List<EndpointFrameSocket> sockets = new List<EndpointFrameSocket>();
        List<RoutingFrameSocket> trunks = new List<RoutingFrameSocket>();

        // if set, minimum set to build composite map from
        public SignalMap FixedMap;

        void RoutePacket(UnpackedFrame frame)
        {
            Console.WriteLine($"{(UInt32)frame.srcid:X8}=>{(UInt32)frame.dstid:X8} {frame.signals.Length} Signals");
            if (frame.dstid == 0xffffffffu)
            {
                // broadcast frame...
                foreach (var socket in sockets.Concat<FrameSocket>(trunks))
                {
                    // but not back where it came in, lest we loop forever...
                    if (frame.origin != socket)
                    {
                        socket.EnqueueSend(frame);
                    }
                }
            }
            else
            {
                var outsock = sockets.Concat<FrameSocket>(trunks).FirstOrDefault(fs => fs.CanRoute(frame.dstid));
                if (outsock != null)
                {
                    // found a match, send it on!
                    outsock.EnqueueSend(frame);
                }
                else
                {
                    // unroutable frames? default route somewhere?
                }
            }
        }

        public void Register(EndpointFrameSocket socket)
        {
            Console.WriteLine($"Registered Socket {socket.Name}");
            socket.OnReceive = RoutePacket;
            if (!sockets.Contains(socket))
            {
                sockets.Add(socket);
            }
            foreach (var trunk in trunks)
            {
                trunk.AnnouncePeers(LocalPeers);
            }

        }

        public void Unregister(EndpointFrameSocket socket)
        {
            Console.WriteLine($"Unregistered Socket {socket.Name}");
            sockets.Remove(socket);
            
            foreach (var trunk in trunks)
            {
                trunk.AnnouncePeers(LocalPeers);
            }

        }

        public void Register(RoutingFrameSocket socket)
        {
            // trunk registering itself...
            Console.WriteLine($"Registered Trunk {socket.Name}");
            socket.OnReceive = RoutePacket;
            trunks.Add(socket);

        }

        public void Unregister(RoutingFrameSocket socket)
        {
            // trunk unregistering itself...
            Console.WriteLine($"Unregistered Trunk {socket.Name}");
            socket.OnReceive = null;
            trunks.Remove(socket);

        }

        public IEnumerable<VarInt> LocalPeers => sockets.Select(s => s.ID);

        public SignalMap BuildCompositeMap()
        {
            return new SignalMap(
                (FixedMap?.All ?? Enumerable.Empty<SignalMap.SignalID>()).Concat(
                    sockets.Select(s => s.Map).SelectMany(m => m?.All ?? Enumerable.Empty<SignalMap.SignalID>())).Distinct());
        }

    }
}
