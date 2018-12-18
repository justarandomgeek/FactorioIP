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
    public class VarIntTests
    {
        [TestMethod()]
        public void EncodeTest()
        {
            var vi = new VarInt(0);
            var result = vi.Encode().ToArray();
            Assert.AreEqual(1, result.Length);
            Assert.AreEqual(0, result[0]);

            vi = new VarInt(1);
            result = vi.Encode().ToArray();
            Assert.AreEqual(1, result.Length);
            Assert.AreEqual(1, result[0]);

            vi = new VarInt(0x7f);
            result = vi.Encode().ToArray();
            Assert.AreEqual(1, result.Length);
            Assert.AreEqual(0x7f, result[0]);

            vi = new VarInt(0x80);
            result = vi.Encode().ToArray();
            Assert.AreEqual(2, result.Length);
            Assert.AreEqual(0xC2, result[0]);
            Assert.AreEqual(0x80, result[1]);

            vi = new VarInt(0x7ff);
            result = vi.Encode().ToArray();
            Assert.AreEqual(2, result.Length);
            Assert.AreEqual(0xDF, result[0]);
            Assert.AreEqual(0xBF, result[1]);

            vi = new VarInt(0x800);
            result = vi.Encode().ToArray();
            Assert.AreEqual(3, result.Length);
            Assert.AreEqual(0xE0, result[0]);
            Assert.AreEqual(0xA0, result[1]);
            Assert.AreEqual(0x80, result[2]);

            vi = new VarInt(0xFFFF);
            result = vi.Encode().ToArray();
            Assert.AreEqual(3, result.Length);
            Assert.AreEqual(result[0], 0xEF);
            Assert.AreEqual(result[1], 0xBF);
            Assert.AreEqual(result[2], 0xBF);

            vi = new VarInt(0x10000);
            result = vi.Encode().ToArray();
            Assert.AreEqual(4, result.Length);
            Assert.AreEqual(0xF0, result[0]);
            Assert.AreEqual(0x90, result[1]);
            Assert.AreEqual(0x80, result[2]);
            Assert.AreEqual(0x80, result[3]);

            vi = new VarInt(0x1FFFFF);
            result = vi.Encode().ToArray();
            Assert.AreEqual(4, result.Length, 4);
            Assert.AreEqual(0xF7, result[0]);
            Assert.AreEqual(0xBF, result[1]);
            Assert.AreEqual(0xBF, result[2]);
            Assert.AreEqual(0xBF, result[3]);
                       
            vi = new VarInt(0x200000);
            result = vi.Encode().ToArray();
            Assert.AreEqual(5, result.Length);
            Assert.AreEqual(0xF8, result[0]);
            Assert.AreEqual(0x88, result[1]);
            Assert.AreEqual(0x80, result[2]);
            Assert.AreEqual(0x80, result[3]);
            Assert.AreEqual(0x80, result[4]);

            vi = new VarInt(0x3FFFFFF);
            result = vi.Encode().ToArray();
            Assert.AreEqual(5, result.Length);
            Assert.AreEqual(0xFB, result[0]);
            Assert.AreEqual(0xBF, result[1]);
            Assert.AreEqual(0xBF, result[2]);
            Assert.AreEqual(0xBF, result[3]);
            Assert.AreEqual(0xBF, result[4]);

            vi = new VarInt(0x4000000);
            result = vi.Encode().ToArray();
            Assert.AreEqual(6, result.Length);
            Assert.AreEqual(0xFC, result[0]);
            Assert.AreEqual(0x84, result[1]);
            Assert.AreEqual(0x80, result[2]);
            Assert.AreEqual(0x80, result[3]);
            Assert.AreEqual(0x80, result[4]);
            Assert.AreEqual(0x80, result[5]);

            vi = new VarInt(0xFFFFFFFF);
            result = vi.Encode().ToArray();
            Assert.AreEqual(6, result.Length);
            Assert.AreEqual(0xFF, result[0]);
            Assert.AreEqual(0xBF, result[1]);
            Assert.AreEqual(0xBF, result[2]);
            Assert.AreEqual(0xBF, result[3]);
            Assert.AreEqual(0xBF, result[4]);
            Assert.AreEqual(0xBF, result[5]);

        }

        [TestMethod()]
        public void TakeTest()
        {
            var bytes = new byte[]
            {
                0x01,
                0x7f,
                0xC2, 0x80, 
                0xDF, 0xBF,
                0xE0, 0xA0, 0x80,
                0xEF, 0xBF, 0xBF,
                0xF0, 0x90, 0x80, 0x80,
                0xF7, 0xBF, 0xBF, 0xBF,
                0xF8, 0x88, 0x80, 0x80, 0x80,
                0xFB, 0xBF, 0xBF, 0xBF, 0xBF,
                0xFC, 0x84, 0x80, 0x80, 0x80, 0x80,
                0xFF, 0xBF, 0xBF, 0xBF, 0xBF, 0xBF,
                0x00,
                0x01,
            };

            var vilist = VarInt.TakeAll(new ArraySegment<byte>(bytes)).ToArray();

            Assert.AreEqual(12, vilist.Length);
            Assert.AreEqual<VarInt>(1, vilist[0]);
            Assert.AreEqual<VarInt>(0x7F, vilist[1]);
            Assert.AreEqual<VarInt>(0x80, vilist[2]);
            Assert.AreEqual<VarInt>(0x7FF, vilist[3]);
            Assert.AreEqual<VarInt>(0x800, vilist[4]);
            Assert.AreEqual<VarInt>(0xFFFF, vilist[5]);
            Assert.AreEqual<VarInt>(0x10000, vilist[6]);
            Assert.AreEqual<VarInt>(0x1FFFFF, vilist[7]);
            Assert.AreEqual<VarInt>(0x200000, vilist[8]);
            Assert.AreEqual<VarInt>(0x3FFFFFF, vilist[9]);
            Assert.AreEqual<VarInt>(0x4000000, vilist[10]);
            Assert.AreEqual<VarInt>(0xFFFFFFFF, vilist[11]);


        }
    }
}