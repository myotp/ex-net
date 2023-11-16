# ExNet

## TCP/IP stack written in Elixir ##

ExNet - a custom TCP/IP protocol stack from scratch using Elixir, enabling fundamental functionalities of the TCP/IP. It also contains a simplified DNS and HTTP client implementation as a demonstration of the entire stack.

## DNS

```elixir
iex(2)> {:ok, ip_addr} = ExDNS.find_ip_address("ifconfig.me")
{:ok, 580939665}
iex(3)> IPv4.ip_addr_to_string(ip_addr)
"34.160.111.145"
```

## UDP

```elixir
iex(1)> {:ok, socket} = ExUDP.open(8888)
{:ok, #Reference<0.3071399119.740818950.172299>}
iex(2)> ExUDP.send(socket, "192.168.1.90", 9090, "Hello, from ex-net")
:ok
```

## ARP
```elixir
iex(1)> {:ok, mac_addr} = ExARP.find_mac_address("192.168.1.1")
{:ok, 64727626581}
iex(2)> ExNet.Core.Ethernet.mac_i2s(mac_addr)
"00:0f:12:11:33:55"
```
