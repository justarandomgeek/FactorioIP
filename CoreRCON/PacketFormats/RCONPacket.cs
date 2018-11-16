using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace CoreRCON.PacketFormats
{
	public class RCONPacket
	{
		public string Body
        {
            get => Encoding.UTF8.GetString(RawBody);
            private set { RawBody = Encoding.UTF8.GetBytes(value + "\0"); }
        }
        public byte[] RawBody { get; private set; }
        public int Id { get; private set; }
		public PacketType Type { get; private set; }

		/// <summary>
		/// Create a new packet.
		/// </summary>
		/// <param name="id">Some kind of identifier to keep track of responses from the server.</param>
		/// <param name="type">What the server is supposed to do with the body of this packet.</param>
		/// <param name="body">The actual information held within.</param>
		public RCONPacket(int id, PacketType type, string body)
		{
			Id = id;
			Type = type;
			Body = body;
		}

        /// <summary>
		/// Create a new packet.
		/// </summary>
		/// <param name="id">Some kind of identifier to keep track of responses from the server.</param>
		/// <param name="type">What the server is supposed to do with the body of this packet.</param>
		/// <param name="body">The actual information held within.</param>
		public RCONPacket(int id, PacketType type, byte[] body)
        {
            Id = id;
            Type = type;
            RawBody = body;
        }

        public override string ToString() => Body;

		/// <summary>
		/// Converts a buffer to a packet.
		/// </summary>
		/// <param name="buffer">Buffer to read.</param>
		/// <returns>Created packet.</returns>
		internal static RCONPacket FromBytes(byte[] buffer)
		{
			if (buffer == null) throw new NullReferenceException("Byte buffer cannot be null.");
			if (buffer.Length < 4) throw new InvalidDataException("Buffer does not contain a size field.");
			if (buffer.Length > Constants.MAX_PACKET_SIZE) throw new InvalidDataException("Buffer is too large for an RCON packet.");

			int size = BitConverter.ToInt32(buffer, 0);

			if (size < 10) throw new InvalidDataException("Packet received was invalid.");

			int id = BitConverter.ToInt32(buffer, 4);
			PacketType type = (PacketType)BitConverter.ToInt32(buffer, 8);

			try
			{
                byte[] rawBody = new byte[size - 9];
                Array.Copy(buffer, 12, rawBody, 0, size - 10);
				return new RCONPacket(id, type, rawBody);
			}
			catch (Exception ex)
			{
				Console.Error.WriteLine($"{DateTime.Now} - Error reading RCON packet from server: " + ex.Message);
				return new RCONPacket(id, type, "");
			}
		}

		/// <summary>
		/// Serializes a packet to a byte array for transporting over a network.
		/// </summary>
		/// <returns>Byte array with each field.</returns>
		internal byte[] ToBytes()
		{
			int bl = RawBody.Length;

			using (var packet = new MemoryStream(12 + bl))
			{
				packet.Write(BitConverter.GetBytes(9 + bl), 0, 4);
				packet.Write(BitConverter.GetBytes(Id), 0, 4);
				packet.Write(BitConverter.GetBytes((int)Type), 0, 4);
				packet.Write(RawBody, 0, bl);
				packet.Write(new byte[] { 0 }, 0, 1);

				return packet.ToArray();
			}
		}
	}
}