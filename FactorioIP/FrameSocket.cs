using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FactorioIP
{
    public interface FrameSocket
    {
        Action<UnpackedFrame> OnReceive { get; set; }
        void EnqueueSend(UnpackedFrame frame);

        SignalMap Map { get; }
        bool CanRoute(VarInt dst);

        string Name { get; }
    }

    public interface EndpointFrameSocket : FrameSocket
    {
        VarInt ID { get; }
    }

    public interface RoutingFrameSocket : FrameSocket
    {
        void AnnouncePeers(IEnumerable<VarInt> id);
        IEnumerable<VarInt> RoutablePeers { get; }
    }
}
