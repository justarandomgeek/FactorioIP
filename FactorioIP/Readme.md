
# FactorioIP: Circuit inter-networking via external bridging

FactorioIP is a bridge that allows connecting multiple factorio worlds together in a circuit internetwork and optionally conecting to the public IPv6 network using [feathernet](..\Feathernet.md).

Factorio works can be connected by listing thier RCON config. The factorio world must have the Routable Combinators mod loaded to provide in-world support. If used with IPv6, the padding signals should be enabled. A signal map will be retreived from Factorio on connection.

```
FactorioIP.exe RCON:localhost:12345:password
```

A `TCPL` connection may be listed to listen on that port for other FactorioIP instances, and a `TCP` connect may be used as a client. `TCP/L` connections will use a signal map composed of the union of all signal maps on the client side. Signals not present in this map will be dropped by the server when forwarding frames.

```
hosta> FactorioIP.exe RCON:localhost:12345:password TCPL:13579
hostb> FactorioIP.exe RCON:localhost:12345:password TCP:hosta:13579
```

To connect to live network, a `GRE` connection may be listed. Currently only GRE over IPv4 is supported, because I couldn't get my router to do GRE over IPv6 to test with. GRE sockets use the signal map defined by feathernet.

```
FactorioIP RCON:localhost:12345:password GRE:somerouter
```

Additionally, a dummy `MAP` peer may be added to load a fixed map from a json file. If multiple `MAP` peers are listed, the last one will be used.

```
FactorioIP MAP:mapfile.json
```

```json 
[
  {"name":"signal-A","type":"virtual"},
  {"name":"signal-B","type":"virtual"},
  ...
]
```




All connetion types may be repeated and combined freely on any node, though the current routing won't support much more than a simple star network with a single node listening at the center.

```
hosta> FactorioIP.exe RCON:localhost:12345:password GRE:somerouter TCPL:13579
hostb> FactorioIP.exe RCON:localhost:12345:password TCP:hosta:13579
hostc> FactorioIP.exe RCON:localhost:12345:password TCP:hosta:13579
hostd> FactorioIP.exe RCON:localhost:12345:password TCP:hosta:13579
hoste> FactorioIP.exe RCON:otherhost:12345:password RCON:anotherhost:12345:password TCP:hosta:13579
```



The GRE connection type is verified to work with the following OpenWRT network config:

```
etc/config/network:
config interface 'gretun'
	#router's IP in lan subnet
	option ipaddr '10.42.2.1'
	#FactorioIP node's IP in lan subnet
	option peeraddr '10.42.2.111'
	#we have to stretch signals to make 1280, please no more...
	#this also means we have plenty of headroom for the tunnelling headers!
	option mtu '1280'
	option proto 'gre'

config interface 'greif'
	option proto 'static'
	option ifname '@gretun'
	#unused IPv4 subnet - this goes on the FactorioIP link
	#nothing using it yet, no IPv4 circuits built.
	option ipaddr '10.42.10.1'
	option netmask '255.255.255.0'
	#assign an IPv6 prefix...
	option ip6assign '64'
	option ip6hint '3'
	option mtu '1280'
	option broadcast '10.42.10.255'

etc/config/dhcp:
config dhcp 'greif'
	option start '100'
	option leasetime '12h'
	option limit '150'
	option interface 'greif'
	option ra 'server'
```
