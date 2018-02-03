using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

namespace FactorioIP
{
    class SocketIOClient
    {
        ClientWebSocket wsock;
        string sid;
        int pingTimeout;
        int pingInterval;

        CancellationToken rcvTok = new CancellationToken();
        CancellationToken sndTok = new CancellationToken();
        byte[] wsrcvbuf = new byte[64000];

        JavaScriptSerializer json = new JavaScriptSerializer();

        Dictionary<string, Action<dynamic>> eventHandlers = new Dictionary<string, Action<dynamic>>();

        public void Connect(string hostname, UInt16 port, bool secure = false)
        {
            wsock = new ClientWebSocket();
            // default buffers aren't big enough for full MTU packets
            wsock.Options.SetBuffer(32000, 32000);
            wsock.ConnectAsync(new Uri($"{(secure?"wss":"ws")}://{hostname}:{port}/socket.io/?EIO=3&transport=websocket"), rcvTok).Wait();
            wsock.ReceiveAsync(new ArraySegment<byte>(wsrcvbuf), rcvTok).ContinueWith(CompleteReceive);
            
        }


        public void On(string eventName, Action<dynamic> handler)
        {
            eventHandlers[eventName] = handler;
        }

        public void Emit(string eventName, dynamic data = null)
        {
            var eventdata = data == null ? new object[] { eventName } : new object[] { eventName, data };
            var eventstring = "42" + json.Serialize(eventdata);

            Console.WriteLine("socket.io emit " + eventName);
            wsock.SendAsync(new ArraySegment<byte>(Encoding.UTF8.GetBytes(eventstring)), WebSocketMessageType.Text, true, sndTok).Wait();
        }

        void Ping(string text = null)
        {
            Console.WriteLine("engine.io ping " + text);
            wsock.SendAsync(new ArraySegment<byte>(Encoding.UTF8.GetBytes("2" + text)), WebSocketMessageType.Text, true, sndTok)
                .ContinueWith(t=>Task.Delay(pingInterval).ContinueWith((tt)=>Ping()));
        }


        int RcvOffset = 0;

        void CompleteReceive(Task<WebSocketReceiveResult> t)
        {
            try
            {
                switch ((char)wsrcvbuf[RcvOffset])
                {
                    case '0': // open
                        Console.WriteLine("engine.io open");
                        var conninfo = json.Deserialize<dynamic>(Encoding.UTF8.GetString(wsrcvbuf, RcvOffset+1, t.Result.Count - 1));
                        sid = conninfo["sid"];
                        pingTimeout = conninfo["pingTimeout"];
                        pingInterval = conninfo["pingInterval"];
                        Ping("test");
                        break;
                    case '4': // message
                        switch ((char)wsrcvbuf[RcvOffset+1])
                        {
                            case '0': // connect (socketio)
                                Console.WriteLine("socket.io connect");
                                break;
                            case '2': // event
                                var eventdata = json.Deserialize<dynamic>(Encoding.UTF8.GetString(wsrcvbuf, RcvOffset+2, t.Result.Count - 2));
                                Console.WriteLine("socket.io event " + eventdata[0]);
                                if (eventHandlers.ContainsKey(eventdata[0]))
                                {
                                    eventHandlers[eventdata[0]](eventdata[1]);
                                }
                                break;

                            // ignore the rest...
                            case '1': // disconnect (socketio)
                            case '3': // ack
                            case '4': // error
                            case '5': // binary event
                            case '6': // binary ack
                            default:
                                Console.WriteLine("Unhandled Socket.IO packet " + Encoding.UTF8.GetString(wsrcvbuf, RcvOffset + 2, t.Result.Count - 2));
                                break;
                        }
                        break;

                    case '3': // pong   
                        Console.WriteLine("engine.io pong");
                        break;

                    // just ignore the rest for now...
                    case '1': // request close
                    case '2': // ping                 
                    case '5': // upgrade
                    case '6': // noop
                    default:


                        Console.WriteLine("Unhandled Engine.IO packet " + Encoding.UTF8.GetString(wsrcvbuf, RcvOffset + 1, t.Result.Count - 1));
                        break;
                }
            }
            catch
            {
                Console.WriteLine("Failed Parse: " + Encoding.UTF8.GetString(wsrcvbuf, RcvOffset, t.Result.Count));


                RcvOffset += t.Result.Count;
            }

            wsock.ReceiveAsync(new ArraySegment<byte>(wsrcvbuf, RcvOffset, wsrcvbuf.Length - RcvOffset), rcvTok).ContinueWith(CompleteReceive);
            
        }

    }
}
