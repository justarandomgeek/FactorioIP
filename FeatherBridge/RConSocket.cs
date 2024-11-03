using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;

namespace FeatherBridge
{

    internal class RConMessage
    {
        private readonly UInt32 id;
        private readonly RawRConMessageType type;
        internal readonly IEnumerable<ReadOnlyMemory<byte>> data;
        private readonly bool inbound;

        private enum RawRConMessageType : UInt32
        {
            SERVERDATA_AUTH = 3, // out
            SERVERDATA_AUTH_RESPONSE = 2, // in
            SERVERDATA_EXECCOMMAND = 2, // out
            SERVERDATA_RESPONSE_VALUE = 0, // in
        }

        public UInt32 Id => id;

        public enum RConMessageType
        {
            Auth,
            AuthResponse,
            Exec,
            ExecResponse,
        }
        public RConMessageType Type {
            get {
                if (inbound)
                {
                    switch (type)
                    {
                        case RawRConMessageType.SERVERDATA_AUTH_RESPONSE: return RConMessageType.AuthResponse;
                        case RawRConMessageType.SERVERDATA_RESPONSE_VALUE: return RConMessageType.ExecResponse;
                    }
                }
                else
                {
                    switch (type)
                    {
                        case RawRConMessageType.SERVERDATA_AUTH: return RConMessageType.Auth;
                        case RawRConMessageType.SERVERDATA_EXECCOMMAND: return RConMessageType.Exec;
                    }
                }
                throw new ArgumentOutOfRangeException();
            }
        }

        private RConMessage(UInt32 id, RawRConMessageType type, IEnumerable<ReadOnlyMemory<byte>> data, bool inbound)
        {
            this.id = id;
            this.type = type;
            this.data = data;
            this.inbound = inbound;
        }

        public static RConMessage ReadFromStream(NetworkStream stream)
        {
            byte[] read = new byte[4];

            stream.ReadExactly(read, 0, 4);
            UInt32 size = BitConverter.ToUInt32(read);

            stream.ReadExactly(read, 0, 4);
            UInt32 id = BitConverter.ToUInt32(read);

            stream.ReadExactly(read, 0, 4);
            RawRConMessageType type = (RawRConMessageType)BitConverter.ToUInt32(read);

            // skip 8 from size for id/type
            // and cut 2 at the end for the two nulls
            byte[] data = new byte[size - (8+2)];
            stream.ReadExactly(data, 0, data.Length);

            // read past those two nulls...
            stream.ReadExactly(read, 0, 2);
            
            return new RConMessage(id, type, [ data ], true);
        }

        public void WriteToStream(NetworkStream stream)
        {
            byte[] write = BitConverter.GetBytes(8 + data.Sum(d => d.Length) + 2);
            stream.Write(write, 0, 4);

            write = BitConverter.GetBytes(this.id);
            stream.Write(write, 0, 4);

            write = BitConverter.GetBytes((UInt32)this.type);
            stream.Write(write, 0, 4);

            foreach (var d in this.data)
            {
                stream.Write(d.Span);
            }

            stream.WriteByte(0);
            stream.WriteByte(0);
        }

        public static RConMessage Auth(UInt32 id, string password)
        {
            return new RConMessage(id, RawRConMessageType.SERVERDATA_AUTH, [ Encoding.UTF8.GetBytes(password) ], false);
        }

        public static RConMessage Exec(UInt32 id, IEnumerable<ReadOnlyMemory<byte>> command)
        {
            return new RConMessage(id, RawRConMessageType.SERVERDATA_EXECCOMMAND, command, false);
        }
    }

    internal class RConSocket
    {
        private UInt32 nextid = 1;
        private readonly Queue<ReadOnlyMemory<byte>> packetsIn = new();
        private readonly Queue<IEnumerable<ReadOnlyMemory<byte>>> packetsOut = new();
        private readonly Thread reconnectThread;
        private readonly string hostname;
        private readonly UInt16 port;
        private readonly string password;

        public RConSocket(string hostname, UInt16 port, string password)
        {
            this.hostname = hostname;
            this.port = port;
            this.password = password;
            reconnectThread = new Thread(new ThreadStart(ConnectInternal));
            reconnectThread.Start();
        }

        public void Send(IEnumerable<ReadOnlyMemory<byte>> data)
        {
            packetsOut.Enqueue(data);
        }

        public bool TryReceive(out ReadOnlyMemory<byte> data) {
            return packetsIn.TryDequeue(out data);
        }

        private void ConnectInternal()
        {
            while (true)
            {
                try
                {
                    TcpClient tcpclient = new();
                    tcpclient.Connect(hostname, port);
                    var stream = tcpclient.GetStream();
                    var authid = nextid++;
                    RConMessage.Auth(authid, password).WriteToStream(stream);
                    var response = RConMessage.ReadFromStream(stream);
                    if (response.Type != RConMessage.RConMessageType.AuthResponse || response.Id != authid)
                    {
                        // auth failed
                        Console.WriteLine("RCON auth failed...");

                        Thread.Sleep(30000);
                        continue;
                    }

                    packetsIn.Clear();
                    packetsOut.Clear();
                    var inThread = new Thread(new ThreadStart(() => ReceiveInternal(stream) ));
                    inThread.Start();
                    var outThread = new Thread(new ThreadStart(() => SendInternal(stream) ));
                    outThread.Start();
                    Console.WriteLine("RCON Connected");

                    while (tcpclient.Connected)
                    {
                        Thread.Sleep(100);
                    }

                    inThread.Join();
                    outThread.Join();

                    Console.WriteLine("RCON Disconnected");

                    Thread.Sleep(1000);
                }
                catch (SocketException)
                {
                    Console.WriteLine("RCON Failed to connect...");

                    Thread.Sleep(5000);
                    continue;
                }
            }
        }

        private void SendInternal(NetworkStream stream)
        {
            while (true)
            {
                try
                {
                    while (packetsOut.TryDequeue(out IEnumerable<ReadOnlyMemory<byte>>? data))
                    {
                        RConMessage.Exec(nextid++, data).WriteToStream(stream);
                    }
                }
                catch (IOException)
                {
                    return;
                }

                Thread.Sleep(1);
            }
        }

        private void ReceiveInternal(NetworkStream stream)
        {
            while (true)
            {
                try
                {
                    var message = RConMessage.ReadFromStream(stream);
                    switch (message.Type)
                    {
                        case RConMessage.RConMessageType.ExecResponse:
                            //RConMessage.ReadFromStream always returns exactly one data block, but if it ever does more than one, need to handle it here ...
                            packetsIn.Enqueue(message.data.First());
                            break;
                    }
                }
                catch (IOException)
                {
                    return;
                }
                
            }
        }
    }
}
