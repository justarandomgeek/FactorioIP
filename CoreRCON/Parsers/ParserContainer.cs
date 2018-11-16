using CoreRCON.PacketFormats;
using System;

namespace CoreRCON.Parsers
{
	/// <summary>
	/// Holds callbacks non-generically.
	/// </summary>
	internal class ParserContainer
	{
		internal Action<object> Callback { get; set; }
		internal Func<RCONPacket, bool> IsMatch { get; set; }
		internal Func<RCONPacket, object> Parse { get; set; }

		/// <summary>
		/// Attempt to parse the line, and call the callback if it succeeded.
		/// </summary>
		/// <param name="line">Single line from the server.</param>
		internal void TryCallback(RCONPacket line)
		{
			object result;
			if (TryParse(line, out result))
			{
				Callback(result);
			}
		}

		/// <summary>
		/// Attempt to parse the line into an object.
		/// </summary>
		/// <param name="line">Single line from the server.</param>
		/// <param name="result">Object to parse into.</param>
		/// <returns>False if the match failed or parsing was unsuccessful.</returns>
		private bool TryParse(RCONPacket line, out object result)
		{
			if (!IsMatch(line))
			{
				result = null;
				return false;
			}

			result = Parse(line);
			return result != null;
		}
	}
}