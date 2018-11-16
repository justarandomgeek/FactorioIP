using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FactorioIP
{

    [DebuggerDisplay("{value,nq}")]
    [Serializable]
    public struct VarInt
    {
        UInt32 value;
        public override string ToString() => value.ToString();

        public VarInt(UInt32 u)
        {
            value = u;
        }

        static public implicit operator UInt32(VarInt v) => v.value;
        static public implicit operator VarInt(UInt32 u) => new VarInt(u);

        static public implicit operator byte(VarInt v) => (byte)v.value;
        static public implicit operator VarInt(byte b) => new VarInt((UInt32)b);

        static public implicit operator Int32(VarInt v) => (Int32)v.value;
        static public implicit operator VarInt(Int32 i) => new VarInt((UInt32)i);

        public IEnumerable<byte> Encode()
        {
            byte prefix = 0;
            byte firstmask = 0;
            byte startshift = 0;
            
            if (value < 0x80)
            {
                //--[[1 byte]]
                yield return (byte)value;
                yield break;
            }
            else if (value < 0x07ff)
            {
                //--[[2 bytes]]
                prefix = 0xc0;
                firstmask = 0x1f;
                startshift = 6;
            }
            else if (value < 0xffff)
            {
                //--[[3 bytes]]
                prefix = 0xe0;
                firstmask = 0x0f;
                startshift = 12;
            }
            else if (value < 0x1fffff)
            {
                //--[[4 bytes]]
                prefix = 0xf0;
                firstmask = 0x07;
                startshift = 18;
            }
            else if (value < 0x3ffffff)
            {
                //--[[5 bytes]]
                prefix = 0xf8;
                firstmask = 0x03;
                startshift = 24;
            }
            else
            {
                //--[[6 bytes]]
                prefix = 0xfc;
                firstmask = 0x03;
                startshift = 30;
            }


            yield return (byte)((prefix | ((value >> startshift) & firstmask)));
            for (int shift = startshift - 6; shift >= 0; shift -= 6)
            {
                yield return (byte)((0x80u | ((value >> shift) & 0x3fu)));
            }
        }

        public static (VarInt, IEnumerable<byte>) Take(IEnumerable<byte> data)
        {
            var first = data.FirstOrDefault();
            if (first == 0)
            {
                return (0, data.Skip(1));
            }

            var seq = first < 0x80 ? 1 : first < 0xE0 ? 2 : first < 0xF0 ? 3 : first < 0xF8 ? 4 : first < 0xFC ? 5 : 6;

            if (seq == 1)
            {
                return (first, data.Skip(1));
            }
            else
            {
                UInt32 val = (first & ((1u << (8 - seq)) - 1u));
                data = data.Skip(1);
                for (int i = 1; i < seq; i++)
                {
                    val = (val << 6) | (data.First() & 0x3Fu);
                    data = data.Skip(1);
                }
                return (val, data);
            }
        }

        public static IEnumerable<VarInt> TakeAll(IEnumerable<byte> data)
        {
            while (true)
            {
                VarInt val = 0;
                (val, data) = VarInt.Take(data);
                if (val == 0)
                {
                    yield break;
                }

                yield return val;
            }
        }

    }


    static class VarIntUtil
    {

                
        public static IEnumerable<byte> Pack(this IEnumerable<VarInt> data) => data.SelectMany(d => d.Encode());

        public static string Print(this IEnumerable<VarInt> data) => string.Join(", ", data.Select(d => $"{(UInt32)d:X8}"));

    }

}
