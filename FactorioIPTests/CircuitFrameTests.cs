using Microsoft.VisualStudio.TestTools.UnitTesting;
using FactorioIP;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FactorioIP.Tests
{
    [TestClass()]
    public class UnpackedFrameTests
    {
        [TestMethod()]
        public void PackTest()
        {
            // Test a frame of one real signal...
            var frame = new UnpackedFrame(1, 2, new CircuitFrameValue[] {
                new CircuitFrameValue { type = "virtual", name = "signal-0", count = 42 },
            });

            var pframe = frame.Pack(GREFrameSocket.Feathernet_0_16);


            Assert.AreEqual(3, pframe.payload.Length);
            Assert.AreEqual<VarInt>(3, pframe.payload[0]);
            Assert.AreEqual<VarInt>(1, pframe.payload[1]);
            Assert.AreEqual<VarInt>(42, pframe.payload[2]);

            // Test a frame of one real signal and one bogus one...
            frame = new UnpackedFrame(1, 2, new CircuitFrameValue[] {
                new CircuitFrameValue { type = "virtual", name = "signal-0", count = 42 },
                new CircuitFrameValue { type = "virtual", name = "signal-bogus", count = 1337 },
            });

            pframe = frame.Pack(GREFrameSocket.Feathernet_0_16);


            Assert.AreEqual(3, pframe.payload.Length);
            Assert.AreEqual<VarInt>(3, pframe.payload[0]);
            Assert.AreEqual<VarInt>(1, pframe.payload[1]);
            Assert.AreEqual<VarInt>(42, pframe.payload[2]);

            // Test a frame of one bogus signal...
            frame = new UnpackedFrame(1, 2, new CircuitFrameValue[] {
                new CircuitFrameValue { type = "virtual", name = "signal-bogus", count = 1337 },
            });

            pframe = frame.Pack(GREFrameSocket.Feathernet_0_16);


            Assert.AreEqual(2, pframe.payload.Length);
            Assert.AreEqual<VarInt>(-1, pframe.payload[0]);
            Assert.AreEqual<VarInt>(0, pframe.payload[1]);

            // Test a frame of real signals out of order and with a gap...
            frame = new UnpackedFrame(1, 2, new CircuitFrameValue[] {
                new CircuitFrameValue { type = "virtual", name = "signal-2", count = 31416 },
                new CircuitFrameValue { type = "virtual", name = "signal-0", count = 42 },
                new CircuitFrameValue { type = "virtual", name = "signal-1", count = 1337 },
                new CircuitFrameValue { type = "virtual", name = "signal-8", count = 999 },
            });

            pframe = frame.Pack(GREFrameSocket.Feathernet_0_16);


            Assert.AreEqual(8, pframe.payload.Length);
            Assert.AreEqual<VarInt>(3, pframe.payload[0]);
            Assert.AreEqual<VarInt>(3, pframe.payload[1]);
            Assert.AreEqual<VarInt>(42, pframe.payload[2]);
            Assert.AreEqual<VarInt>(1337, pframe.payload[3]);
            Assert.AreEqual<VarInt>(31416, pframe.payload[4]);
            Assert.AreEqual<VarInt>(11, pframe.payload[5]);
            Assert.AreEqual<VarInt>(1, pframe.payload[6]);
            Assert.AreEqual<VarInt>(999, pframe.payload[7]);

        }

        [TestMethod()]
        public void PackWithZerosTest()
        {
            // Test a frame of one real signal...
            var frame = new UnpackedFrame(1, 2, new CircuitFrameValue[] {
                new CircuitFrameValue { type = "virtual", name = "signal-0", count = 42 },
            });

            var pframe = frame.PackWithZeros(GREFrameSocket.Feathernet_0_16);


            Assert.AreEqual(5, pframe.payload.Length);
            Assert.AreEqual<VarInt>(1, pframe.payload[0]);
            Assert.AreEqual<VarInt>(3, pframe.payload[1]);
            Assert.AreEqual<VarInt>(0, pframe.payload[2]);
            Assert.AreEqual<VarInt>(0, pframe.payload[3]);
            Assert.AreEqual<VarInt>(42, pframe.payload[4]);

            // Test a frame of one real signal and one bogus one...
            frame = new UnpackedFrame(1, 2, new CircuitFrameValue[] {
                new CircuitFrameValue { type = "virtual", name = "signal-0", count = 42 },
                new CircuitFrameValue { type = "virtual", name = "signal-bogus", count = 1337 },
            });

            pframe = frame.PackWithZeros(GREFrameSocket.Feathernet_0_16);


            Assert.AreEqual(5, pframe.payload.Length);
            Assert.AreEqual<VarInt>(1, pframe.payload[0]);
            Assert.AreEqual<VarInt>(3, pframe.payload[1]);
            Assert.AreEqual<VarInt>(0, pframe.payload[2]);
            Assert.AreEqual<VarInt>(0, pframe.payload[3]);
            Assert.AreEqual<VarInt>(42, pframe.payload[4]);

            // Test a frame of one bogus signal...
            frame = new UnpackedFrame(1, 2, new CircuitFrameValue[] {
                new CircuitFrameValue { type = "virtual", name = "signal-bogus", count = 1337 },
            });

            pframe = frame.PackWithZeros(GREFrameSocket.Feathernet_0_16);


            Assert.AreEqual(2, pframe.payload.Length);
            Assert.AreEqual<VarInt>(1, pframe.payload[0]);
            Assert.AreEqual<VarInt>(0, pframe.payload[1]);

            // Test a frame of real signals out of order and with a gap...
            frame = new UnpackedFrame(1, 2, new CircuitFrameValue[] {
                new CircuitFrameValue { type = "virtual", name = "signal-2", count = 31416 },
                new CircuitFrameValue { type = "virtual", name = "signal-0", count = 42 },
                new CircuitFrameValue { type = "virtual", name = "signal-1", count = 1337 },
                new CircuitFrameValue { type = "virtual", name = "signal-8", count = 999 },
            });

            pframe = frame.PackWithZeros(GREFrameSocket.Feathernet_0_16);

            Assert.AreEqual(13, pframe.payload.Length);
            Assert.AreEqual<VarInt>(1, pframe.payload[0]);
            Assert.AreEqual<VarInt>(11, pframe.payload[1]);
            Assert.AreEqual<VarInt>(0, pframe.payload[2]);
            Assert.AreEqual<VarInt>(0, pframe.payload[3]);
            Assert.AreEqual<VarInt>(42, pframe.payload[4]);
            Assert.AreEqual<VarInt>(1337, pframe.payload[5]);
            Assert.AreEqual<VarInt>(31416, pframe.payload[6]);
            Assert.AreEqual<VarInt>(0, pframe.payload[7]);
            Assert.AreEqual<VarInt>(0, pframe.payload[8]);
            Assert.AreEqual<VarInt>(0, pframe.payload[9]);
            Assert.AreEqual<VarInt>(0, pframe.payload[10]);
            Assert.AreEqual<VarInt>(0, pframe.payload[11]);
            Assert.AreEqual<VarInt>(999, pframe.payload[12]);

        }
    }
}