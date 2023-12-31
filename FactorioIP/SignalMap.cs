using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace FactorioIP
{
    public partial class SignalMap
    {
        [Serializable]
        public struct SignalID
        {
            public string type;
            public string name;

            public override readonly string ToString() => $"{type[..1]}:{name}";

            public static implicit operator SignalID((string t, string n) tuple) => new SignalID { type = tuple.t, name = tuple.n };

            public override readonly int GetHashCode() => (type, name).GetHashCode();
            public override bool Equals(object other) => other is SignalID l && Equals(l);
            public readonly bool Equals(SignalID other) => type == other.type && name == other.name;

        }
        readonly List<SignalID> signals;

        public SignalID ByID(UInt32 id) => signals[(int)id-1];
        public UInt32 BySignal(string type, string name) => (UInt32)signals.IndexOf((type,name)) + 1;
        public int Count => signals.Count;

        public SignalMap(IEnumerable<SignalID> signals)
        {
            this.signals = new List<SignalID>(signals);
        }

        public void Add(SignalID newsignal)
        {
            if (!signals.Contains(newsignal)) signals.Add(newsignal);
        }
        public void AddRange(IEnumerable<SignalID> newsignals) => signals.AddRange(newsignals);

        public IEnumerable<SignalID> All => signals.AsReadOnly();
    }
}
