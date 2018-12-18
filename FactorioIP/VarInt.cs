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
            else if (value < 0x0800)
            {
                //--[[2 bytes]]
                prefix = 0xc0;
                firstmask = 0x1f;
                startshift = 6;
            }
            else if (value < 0x10000)
            {
                //--[[3 bytes]]
                prefix = 0xe0;
                firstmask = 0x0f;
                startshift = 12;
            }
            else if (value < 0x200000)
            {
                //--[[4 bytes]]
                prefix = 0xf0;
                firstmask = 0x07;
                startshift = 18;
            }
            else if (value < 0x4000000)
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

        public static (VarInt, ArraySegment<byte>) Take(ArraySegment<byte> data)
        {
            if (data.Count == 0)
            {
                return (0, data);
            }

            var first = data.Array[data.Offset];
            if (first == 0)
            {
                return (0, new ArraySegment<byte>(data.Array, data.Offset + 1, data.Count - 1));
            }

            var seq = first < 0x80 ? 1 : first < 0xE0 ? 2 : first < 0xF0 ? 3 : first < 0xF8 ? 4 : first < 0xFC ? 5 : 6;

            if (seq == 1)
            {
                return (first, new ArraySegment<byte>(data.Array, data.Offset + 1, data.Count - 1));
            }
            else
            {
                UInt32 val = (first & ((1u << (8 - seq)) - 1u));
                
                for (int i = 1; i < seq; i++)
                {
                    val = (val << 6) | (data.Array[data.Offset+i] & 0x3Fu);
                }
                return (val, new ArraySegment<byte>(data.Array, data.Offset + seq, data.Count - seq));
            }
        }

        public static IEnumerable<VarInt> TakeAll(ArraySegment<byte> data)
        {
            while (data.Count > 0)
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

        public static bool operator ==(VarInt left, VarInt right) => left.value == right.value;
        public static bool operator !=(VarInt left, VarInt right) => left.value != right.value;

        public static bool operator ==(VarInt left, UInt32 right) => left.value == right;
        public static bool operator !=(VarInt left, UInt32 right) => left.value != right;

        public static bool operator ==(VarInt left, Int32 right) => left.value == (UInt32)right;
        public static bool operator !=(VarInt left, Int32 right) => left.value != (UInt32)right;

        public override bool Equals(object obj)
        {
            return obj is VarInt vi ? this == vi : obj is UInt32 u ? this == u : obj is Int32 i ? this == i : false;
        }

        public override int GetHashCode()
        {
            return value.GetHashCode();
        }

    }


    static class VarIntUtil
    {

                
        public static IEnumerable<byte> Pack(this IEnumerable<VarInt> data) => data.SelectMany(d => d.Encode());

        public static string Print(this IEnumerable<VarInt> data) => string.Join(", ", data.Select(d => $"{(UInt32)d:X8}"));

    }

}
