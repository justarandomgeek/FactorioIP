// See https://aka.ms/new-console-template for more information


using FeatherBridge;
using System.Text;

var rcon = new RConSocket(args[0], UInt16.Parse(args[1]), args[2]);
var gre = new GRESocket(args[3], args[4]);

int n = 0;
while (true)
{
    while (rcon.TryReceive(out var data))
    {       
        while (!data.IsEmpty)
        {
            var span = data.Span;
            //16bit count of 32bit words
            var count = (UInt16)(span[0] << 8) | span[1];

            //16bit ethertype
            var proto = (UInt16)((span[2] << 8) | span[3]);

            // data (count*4 bytes)
            var payload = data[4..((count+1) * 4)];

            // send it!
            gre.Send(new Packet { ethertype = proto, data = payload });

            // skip the extra 0x0a from rcon...
            data = data[(4 + (count * 4) + 1)..];
            Console.WriteLine($"RCON: type {proto:X4} size {count*4}");
        }
    }

    if (n++ > 15)
    {
        n = 0;

        var outs = new List<ReadOnlyMemory<byte>>
        {
            Encoding.UTF8.GetBytes("/FBtraff ")
        };

        var count = 0;
        while (outs.Sum(o=>o.Length) <= 20*1024 && gre.TryReceive(out var packet))
        {
            if (packet.ethertype == 0x86dd)
            {
                var length = packet.data.Length / 4;
                if (packet.data.Length % 4 != 0)
                {
                    length++;
                }
                var size = new byte[2];
                size[0] = (byte)((length >> 8) & 0xff);
                size[1] = (byte)(length & 0xff);
                //TODO: type on packets going to rcon?
                outs.Add(size);
                outs.Add(packet.data);
                if (packet.data.Length % 4 != 0)
                {
                    outs.Add(new byte[4 - (packet.data.Length % 4)]);
                }
                outs.Add(new byte[2]{ 0xA5, 0xA5 }); // bodge bytes to prevent/detect truncations
                Console.WriteLine($"GRE: type {packet.ethertype:X4} size {packet.data.Length}");
                count++;
            }

        }
        rcon.Send(outs);
        if (count > 0)
        {
            Console.WriteLine($"RCON: sent {count}");
        }
    }
    Thread.Sleep(1);
}

struct Packet
{
    public UInt16 ethertype;
    public ReadOnlyMemory<byte> data;
};

