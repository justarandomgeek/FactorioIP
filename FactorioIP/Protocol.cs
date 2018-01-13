using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;

namespace FactorioIP
{

    static class BytesUtil
    {
        public static byte[] getBytes<T>(T str)
        {
            int size = Marshal.SizeOf(str);
            byte[] arr = new byte[size];
            IntPtr ptr = Marshal.AllocHGlobal(size);

            Marshal.StructureToPtr(str, ptr, true);
            Marshal.Copy(ptr, arr, 0, size);
            Marshal.FreeHGlobal(ptr);

            return arr;
        }

        public static T fromBytes<T>(byte[] arr, int startIndex = 0)
        {
            T str = default(T);

            int size = Marshal.SizeOf(str);
            IntPtr ptr = Marshal.AllocHGlobal(size);

            Marshal.Copy(arr, startIndex, ptr, size);

            str = (T)Marshal.PtrToStructure(ptr, str.GetType());
            Marshal.FreeHGlobal(ptr);

            return str;
        }

        public static IPAddress IPFrom64Pair(UInt64 addr1, UInt64 addr2)
        {
            return new IPAddress(new byte[]
            {
                (byte)(addr1>>56),
                (byte)(addr1>>48),
                (byte)(addr1>>40),
                (byte)(addr1>>32),
                (byte)(addr1>>24),
                (byte)(addr1>>16),
                (byte)(addr1>>8),
                (byte)(addr1>>0),

                (byte)(addr2>>56),
                (byte)(addr2>>48),
                (byte)(addr2>>40),
                (byte)(addr2>>32),
                (byte)(addr2>>24),
                (byte)(addr2>>16),
                (byte)(addr2>>8),
                (byte)(addr2>>0),
            });
        }
    }


    struct IPv4Header
    {
        byte ver_ihl;
        public byte typeOfService;
        public UInt16 totalLen;
        public UInt16 ident;
        public UInt16 flags_fragment;
        public byte ttl;
        public byte protocol;
        public UInt16 checksum;
        UInt32 sourceraw;
        UInt32 destraw;
        // This would be followed by options, if i supported any...

        // break out bitfields as required...
        public byte version => (byte)(ver_ihl >> 4);
        public byte headLen => (byte)(ver_ihl & 0xf);

        [Flags]
        public enum IPFlags
        {
            reserved = 4,
            DontFragment = 2,
            MoreFragments = 1,
        }
        public IPFlags flags => (IPFlags)((flags_fragment>>13)&7);
        public UInt16 fragmentOffset => (UInt16)(flags_fragment & 0x1fff);

        public IPAddress source { get => new IPAddress(sourceraw); set { this.sourceraw = (UInt32)value.Address; } }
        public IPAddress dest { get => new IPAddress(destraw); set { this.destraw = (UInt32)value.Address; } }

        public static IPv4Header FromBytes(byte[] arr, int startIndex = 0)
        {
            var head = BytesUtil.fromBytes<IPv4Header>(arr, startIndex);
            head.totalLen = (UInt16)IPAddress.NetworkToHostOrder((Int16)head.totalLen);
            head.ident = (UInt16)IPAddress.NetworkToHostOrder((Int16)head.ident);
            head.flags_fragment = (UInt16)IPAddress.NetworkToHostOrder((Int16)head.flags_fragment);
            head.checksum = (UInt16)IPAddress.NetworkToHostOrder((Int16)head.checksum);
            //head.sourceraw = (UInt32)IPAddress.NetworkToHostOrder((Int32)head.sourceraw);
            //head.destraw = (UInt32)IPAddress.NetworkToHostOrder((Int32)head.destraw);

            return head;
            
        }
    }

    struct IPv6Header
    {
        UInt32 ver_class_label;
        public UInt16 payloadLen;
        public byte nextHeader;
        public byte hopLimit;
        UInt64 source1;
        UInt64 source2;
        UInt64 dest1;
        UInt64 dest2;
        // This would be followed by options, if i supported any...

        // break out bitfields as required...
        public byte version => (byte)((ver_class_label >> 28) & 0xf);
        public byte trafficClass => (byte)(ver_class_label >> 20);
        public UInt32 label => (UInt32)(ver_class_label & 0x000fffff);

        public IPAddress source => BytesUtil.IPFrom64Pair(source1, source2);
        public IPAddress dest => BytesUtil.IPFrom64Pair(dest1, dest2);

        public UInt16 totalLen => (UInt16)(payloadLen + 40u);

        public static IPv6Header FromBytes(byte[] arr, int startIndex = 0)
        {
            var head = BytesUtil.fromBytes<IPv6Header>(arr, startIndex);
            head.ver_class_label = (UInt32)IPAddress.NetworkToHostOrder((Int32)head.ver_class_label);
            head.payloadLen = (UInt16)IPAddress.NetworkToHostOrder((Int16)head.payloadLen);
            head.source1 = (UInt64)IPAddress.NetworkToHostOrder((Int64)head.source1);
            head.source2 = (UInt64)IPAddress.NetworkToHostOrder((Int64)head.source2);
            head.dest1   = (UInt64)IPAddress.NetworkToHostOrder((Int64)head.dest1);
            head.dest2   = (UInt64)IPAddress.NetworkToHostOrder((Int64)head.dest2);        
            return head;

        }
    }

    struct GREHeader
    {
        public UInt16 flags_ver;
        public UInt16 protocol;

        public static GREHeader FromBytes(byte[] arr, int startIndex = 0)
        {
            var head = BytesUtil.fromBytes<GREHeader>(arr, startIndex);
            head.flags_ver= (UInt16)IPAddress.NetworkToHostOrder((Int16)head.flags_ver);
            head.protocol = (UInt16)IPAddress.NetworkToHostOrder((Int16)head.protocol);
            
            return head;
        }

        public byte[] ToBytes()
        {
            return BytesUtil.getBytes(new GREHeader
            {
                flags_ver = (UInt16)IPAddress.NetworkToHostOrder((Int16)flags_ver),
                protocol = (UInt16)IPAddress.NetworkToHostOrder((Int16)protocol)
            });
        }
    }
}
