using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Reflection.PortableExecutable;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace FactorioIP
{

    class GREFrameSocket: EndpointFrameSocket
    {

        readonly GRESocket gre;

        public Action<UnpackedFrame> OnReceive { get; set ; }

        // TODO: How to select a map here? extra arg to creation?
        public SignalMap Map => SignalMap.Feathernet_0_17;

        // TODO: use remote IPv4 of tunnel? or 00005efe for ISATAP? or something more unique? probably only one GRE tunnel per net...
        public VarInt ID => 0xfffffffe;

        public string Name => gre.Name;
        public override string ToString() => Name;

        public GREFrameSocket(string host, Action<UnpackedFrame> OnReceive = null)
        {
            gre = new GRESocket(host, ReceivedBytes);

            
            this.OnReceive = OnReceive;
        }

        void ReceivedIPV6(byte[] rcvbuf, int startidx)
        {
            var v6inHeader = IPv6Header.FromBytes(rcvbuf, startidx);
            Console.WriteLine($"Type: {v6inHeader.nextHeader} Payload: {v6inHeader.payloadLen} From: {v6inHeader.source} To: {v6inHeader.dest}");
            if (v6inHeader.payloadLen + 40 <= ((Map.Count - 2) * 4))
            {
                if (v6inHeader.nextHeader == 44)
                {
                    Console.WriteLine("Fragmented packet dropped");
                }
                else
                {
                    var circpacket = packet_to_circuit(rcvbuf, startidx, v6inHeader.totalLen).Unpack();
                    circpacket.origin = this;
                    OnReceive?.Invoke(circpacket);
                }
            }
            else
            {
                Console.WriteLine("Too large");
            }
        }

        void ReceivedBytes(byte[] rcvbuf)
        {
            // convert to signals and OnRecieve()
            var GREHead = GREHeader.FromBytes(rcvbuf, 0);
            if (GREHead.flags_ver != 0) return; // don't support any GRE flags, version is always 0

            // convert inner to json for clusterio and submit... for now we only have v6 inner
            switch (GREHead.protocol)
            {
                case 0x86dd:
                    ReceivedIPV6(rcvbuf, 4);
                    return;
                default:
                    return;
            }
        }

        PackedFrame packet_to_circuit(byte[] buffer, int startAt, int size)
        {
            var frame = new List<VarInt>
            {
                1, // firstsignal = 1 we start at the beginning of the map...
                ((size + 3) / 4) + 2, // sigcount = enough signals to hold all the bytes plus two for feathernet header...

                0, // grey = broadcast / placeholder for feathernet dest
                1 // white = 1 to mark feathernet map
            };

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

            return new PackedFrame(dstid, srcid, frame, Map);
        }

        public void EnqueueSend(UnpackedFrame frame)
        {
            // format and hand to gre...
            UInt16 type = 0;
            var size = frame.signals.Length * 4;

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
                var pframe = frame.PackWithZeros(Map);
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
                Console.WriteLine($"Unrecognized GRE packet type=0x{type:x4} size={size}, signals={frame.signals.Length}");
            }
        }

        
        public bool CanRoute(VarInt dst)
        {
            return dst == ID;
        }

    }
}
