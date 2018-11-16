using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Net;
using System.Net.Sockets;
using System.Web.Script.Serialization;
using System.Net.Http;
using System.IO;
using System.Collections.Specialized;
using System.Net.WebSockets;
using System.Threading;

using CoreRCON;
using CoreRCON.Parsers.Standard;

namespace FactorioIP
{
    partial class Program
    {
        public static int uniqueID = new Random().Next();
        public static void Main(string[] args)
        {
            var router = new FrameRouter();
            foreach (var item in args)
            {
                if (item.StartsWith("GRE:"))
                {
                    // GRE;hostname
                    router.Register(new GREFrameSocket(item.Substring(4)));
                }
                else if (item.StartsWith("RCON:"))
                {
                    // RCON:host;port;password
                    var parts = item.Substring(5).Split(';');

                    router.Register(new RConSocket(parts[0], UInt16.Parse(parts[1]), parts[2]));
                }
                else if (item.StartsWith("TCP:"))
                {
                    // TCP:host;port
                    var parts = item.Substring(4).Split(';');

                    new TCPFrameSocket(parts[0], UInt16.Parse(parts[1]), router);
                }
                else if (item.StartsWith("TCPL:"))
                {
                    // TCPL:port
                    var port = UInt16.Parse(item.Substring(5));

                    new TCPFrameSocketListener(port, router);
                }
                else if (item.StartsWith("MAP:"))
                {
                    // MAP:filename.json
                    var port = item.Substring(4);

                    // just load json map as a dummy peer that doesn't route anything
                    //router.FixedMap = 
                }
                else
                {
                    Console.WriteLine($"Unrecognized argument: \"{item}\"");
                }
            }

            //router.Register(new GREFrameSocket("10.42.2.1"));
            //router.Register(new RConSocket("localhost", 12345, "password"));

            while (true)
            {
                //TODO: some status display? console interaction? add new peers/kill existing ones?
                Thread.Sleep(100);
            }
            
        }        
    }
}
