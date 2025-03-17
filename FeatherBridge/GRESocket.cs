using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;

namespace FeatherBridge
{
    internal class GRESocket
    {
        private readonly Socket gresock;
        private Queue<Packet> packetsIn = new Queue<Packet>();
        private Queue<Packet> packetsOut = new Queue<Packet>();
        private Thread inThread;
        private Thread outThread;


        public GRESocket(string host, string? localendp)
        {
            // set up a socket for GRE=47, listen on any address...
            gresock = new Socket(AddressFamily.InterNetworkV6, SocketType.Raw, (ProtocolType)47);
            gresock.Bind(new IPEndPoint(localendp!=null ? IPAddress.Parse(localendp) : IPAddress.IPv6Any, 0));

            // set default receive from
            gresock.Connect(host, 0);

            inThread = new Thread(new ThreadStart(ReceiveInternal));
            inThread.Start();
            outThread = new Thread(new ThreadStart(SendInternal));
            outThread.Start();
        }

        public void Send(Packet data)
        {
            packetsOut.Enqueue(data);
        }

        public bool TryReceive(out Packet data)
        {
            return packetsIn.TryDequeue(out data);
        }

        public int ReceiveWaiting => packetsIn.Count;

        private void SendInternal()
        {
            while (true)
            {
                while (packetsOut.TryDequeue(out Packet p))
                {
                    var span = p.data.Span;
                    var size = p.data.Length + 4;

                    switch (p.ethertype)
                    {
                        case 0x86dd:
                                    // ip payload size        + header + gre header
                            var ipsize = ((span[4] << 8) | span[5]) + 40     + 4 ;
                            if ((ipsize & 0x3) != 0)
                            {
                                ipsize = (ipsize & ~3) + 4;
                            }

                            if (ipsize >= size)
                            {
                                size = ipsize;
                            }
                            else
                            {
                                Console.WriteLine($"invalid ipsize! {ipsize} {size}");
                            }

                            break;
                        default:
                            break;
                    }

                    var dout = new byte[size];
                    dout[0] = 0; // flags
                    dout[1] = 0; // version

                    // ethertype
                    dout[2] = (byte)((p.ethertype >> 8) & 0xff);
                    dout[3] = (byte)(p.ethertype & 0xff);

                    // payload
                    p.data.CopyTo(new Memory<byte>(dout, 4, p.data.Length));
                    gresock.Send(dout);
                }
                Thread.Sleep(1);
            }
        }

        private void ReceiveInternal()
        {
            while (true)
            {
                var data = new byte[1500];
                var received = gresock.Receive(data);
                if (received > 0)
                {
                    //read and remove tunnel header
                    if (data[0] != 0 || data[1] != 0)
                    {
                        // flags & version fields not zero, drop it...
                        continue;
                    }

                    // ethertype
                    var proto = (UInt16)((data[2] << 8) | data[3]);
                    packetsIn.Enqueue(new Packet { ethertype = proto, data = new ReadOnlyMemory<byte>(data, 4, received - 4) });
                }
            }
        }
    }
}
