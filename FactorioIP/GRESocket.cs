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
    public struct TypeAndPacket
    {
        public UInt16 Type;
        public byte[] Data;
    }

    class GRESocket
    {
        
        Socket gresock;
        CancellationToken rcvTok = new CancellationToken();
        CancellationToken sndTok = new CancellationToken();
        Queue<TypeAndPacket> sendbuf = new Queue<TypeAndPacket>();

        Task rcvTask;
        Task sndTask;

        public Action<byte[]> OnReceive { get; set; }

        public GRESocket(string host, Action<byte[]> OnReceive)
        {
            // set up a socket for GRE=47, listen on any address...
            gresock = new Socket(SocketType.Raw, (ProtocolType)47);
            gresock.Bind(new IPEndPoint(IPAddress.Any, 0));

            // set default receive from
            gresock.Connect(host, 0);

            this.OnReceive = OnReceive;

            rcvTask = ReceiveTask();
            sndTask = SendTask();

        }
        

        async Task ReceiveTask()
        {
            
            
            while (!rcvTok.IsCancellationRequested)
            {
                var data = new byte[1500];
                await Task.Factory.FromAsync(
                    (callback, state) => 
                    gresock.BeginReceive(data, 0, data.Length, SocketFlags.None,
                        callback, state)
                    ,
                    gresock.EndReceive,null);

                OnReceive?.Invoke(data);
            }

        }

        public void EnqueueSend(TypeAndPacket packet)
        {
            sendbuf.Enqueue(packet);
        }

        async Task SendTask()
        {
            while (!sndTok.IsCancellationRequested)
            {
                if (sendbuf.Count > 0)
                {
                    var payload = sendbuf.Dequeue();

                    GREHeader outhead = new GREHeader{ flags_ver = 0, protocol = payload.Type };

                    //TODO: callback to print packet now? maybe another task?
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
                            break;
                        default:
                            break;
                    }

                    var packet = new List<ArraySegment<byte>>{
                        new ArraySegment<byte>(outhead.ToBytes()),
                        new ArraySegment<byte>(payload.Data)
                    };

                    await Task.Factory.FromAsync(
                        (callback, state) =>
                        gresock.BeginSend(packet, SocketFlags.None,
                            callback, state)
                        ,
                        gresock.EndSend, null);
                }
                else
                {
                    //TODO: better way to wait for new packets?
                    await Task.Delay(1, sndTok);
                }
            }

        }


    }
}
