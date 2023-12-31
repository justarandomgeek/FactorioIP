using System;
using System.Collections.Generic;
using System.Linq;
using System.IO;
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
                    // GRE:hostname
                    router.Register(new GREFrameSocket(item[4..]));
                }
                else if (item.StartsWith("RCON:"))
                {
                    // RCON:host:port:password
                    var parts = item[5..].Split(':');
                    if (parts.Length == 3)
                    {
                        var rcon = new RConSocket(parts[0], UInt16.Parse(parts[1]), parts[2],router.Register,router.Unregister);
                    }
                    else if (parts.Length > 3)
                    {
                        var first = string.Join(":", parts.Take(parts.Length - 2));
                        var rest = parts.Skip(parts.Length - 2).ToArray();
                        router.Register(new RConSocket(first, UInt16.Parse(rest[0]), rest[1]));
                    }
                    else
                    {
                        Console.WriteLine($"Invalid RCON argument: \"{item}\"");
                    }


                }
                else if (item.StartsWith("TCP:"))
                {
                    // TCP:host:port
                    var parts = item[4..].Split(':');
                    if (parts.Length == 2)
                    {
                        new TCPFrameSocket(parts[0], UInt16.Parse(parts[1]), router);
                    }
                    else if (parts.Length > 2)
                    {
                        var first = string.Join(":", parts.Take(parts.Length - 1));
                        var rest = parts.Last();
                        new TCPFrameSocket(first, UInt16.Parse(rest), router);
                    }
                    else
                    {
                        Console.WriteLine($"Invalid TCP argument: \"{item}\"");
                    }
                    
                }
                else if (item.StartsWith("TCPL:"))
                {
                    // TCPL:port
                    var port = UInt16.Parse(item[5..]);

                    new TCPFrameSocketListener(port, router);
                }
                else if (item.StartsWith("MAP:"))
                {
                    // MAP:filename.json
                    var path = item[4..];

                    var mapjson = new FileInfo(path).OpenText().ReadToEnd();

                    var map = System.Text.Json.JsonSerializer.Deserialize<IEnumerable<Dictionary<string, string>>>(mapjson);

                    var siglist = map.Select(d => new SignalMap.SignalID { type = (string)d["type"], name = (string)d["name"] });

                    router.FixedMap = new SignalMap(siglist);

                    
                }
                else
                {
                    Console.WriteLine($"Unrecognized argument: \"{item}\"");
                }
            }


            while (true)
            {
                //TODO: some status display? console interaction? add new peers/kill existing ones?
                Thread.Sleep(100);
            }
            
        }        
    }
}
