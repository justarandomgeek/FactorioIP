using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FactorioIP
{
    public class PackedFrame
    {
        public readonly VarInt dstid;
        public readonly VarInt srcid;
        public readonly VarInt[] payload;
        public readonly SignalMap map;

        public PackedFrame(ArraySegment<byte> bytes, SignalMap map)
        {
            (dstid, bytes) = VarInt.Take(bytes);
            (srcid, bytes) = VarInt.Take(bytes);
            payload = VarInt.TakeAll(bytes).ToArray();
            this.map = map;
        }

        internal PackedFrame(VarInt dst, VarInt src, IEnumerable<VarInt> data, SignalMap map)
        {
            dstid = dst;
            srcid = src;
            payload = data.ToArray();
            this.map = map;
        }

        public UnpackedFrame Unpack()
        {
            var i = 0u;
            List<CircuitFrameValue> signals = [];

            while (i < payload.Length)
            {
                UInt32 first_in_segment = payload[i++];
                UInt32 sigs_in_segment = payload[i++];
                for (var j = 0u; j < sigs_in_segment; j++)
                {
                    var value = (Int32)payload[i + j];
                    if (value != 0)
                    {
                        var mapped = map.ByID(first_in_segment + j);
                        signals.Add(
                            new CircuitFrameValue
                            {
                                type = mapped.type,
                                name = mapped.name,
                                count = value
                            });
                    }
                }
                i += sigs_in_segment;
            }

            return new UnpackedFrame(dstid, srcid, signals);

        }

        public IEnumerable<byte> Encode() => Enumerable.Concat(new[] { dstid, srcid }, payload).Pack();
    }

    [DebuggerDisplay("{type,nq}:{name,nq} = {count}")]
    public struct CircuitFrameValue
    {
        public string name;
        public string type;
        public VarInt count;

        public override readonly string ToString() => $"{type[0]}:{name} = {count}";
    }

    
    public class UnpackedFrame
    {
        public readonly VarInt dstid;
        public readonly VarInt srcid;
        public readonly CircuitFrameValue[] signals;

        public FrameSocket origin;

        internal UnpackedFrame(VarInt dst, VarInt src, IEnumerable<CircuitFrameValue> sigs)
        {
            dstid = dst;
            srcid = src;
            signals = sigs.ToArray();
        }

        public PackedFrame Pack(SignalMap map)
        {
            var sigs = signals.Select(s => new { signal = s, id = map.BySignal(s.type, s.name) }).Where(s => s.id != 0).OrderBy(s => s.id).ToArray();
            VarInt lastid = UInt32.MaxValue;
            VarInt first_in_segment = UInt32.MaxValue;
            VarInt sigs_in_segment = 0u;
            List<VarInt> segment_data = [];
            IEnumerable<VarInt> payload_data = Enumerable.Empty<VarInt>();
            foreach (var item in sigs)
            {
                if (item.id == lastid + 1)
                {
                    // just add the value and increment both counters
                    sigs_in_segment++;
                    segment_data.Add(item.signal.count);
                }
                else
                {
                    if (lastid != UInt32.MaxValue)
                    {
                        // write out first in segment, count, data[]
                        payload_data = payload_data.Concat(new[] { first_in_segment, sigs_in_segment }).Concat(segment_data);
                    }
                    // reset counters...
                    first_in_segment = item.id;
                    sigs_in_segment = 1;
                    segment_data = [item.signal.count];
                }
                lastid = item.id;
            }

            //last segment...
            payload_data = payload_data.Concat(new[] { first_in_segment, sigs_in_segment }).Concat(segment_data);


            return new PackedFrame(dstid, srcid, payload_data.ToArray(),map);

        }

        public PackedFrame PackWithZeros(SignalMap map)
        {
            var count = this.signals.Max(cfv => map.BySignal(cfv.type,cfv.name));
            var pf = new PackedFrame(dstid, srcid, new VarInt[count + 2],map);
            pf.payload[0] = 1;
            pf.payload[1] = count;
            for (var i = 2u; i < pf.payload.Length; i++)
            {
                var mapping = map.ByID(i-1);
                pf.payload[i] = signals.FirstOrDefault(s => s.type == mapping.type && s.name == mapping.name).count;
            }
            return pf;
        }
    }
}
