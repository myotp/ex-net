# ExNet

## TCP/IP stack written in Elixir ##

ExNet - a custom TCP/IP protocol stack from scratch using Elixir, enabling fundamental functionalities of the TCP/IP. It also contains a simplified DNS and HTTP client implementation as a demonstration of the entire stack.

## TCP

Remote machine
```elixir
iex(1)> {:ok, socket} = :gen_tcp.listen(6789, [:binary, packet: 0, reuseaddr: true, active: false])
{:ok, #Port<0.3>}
iex(2)> {:ok, socket} = :gen_tcp.accept(socket)
{:ok, #Port<0.4>}
iex(3)> :gen_tcp.send(socket, "hello")
:ok
iex(4)> :gen_tcp.send(socket, "123")
:ok
iex(5)> :gen_tcp.recv(socket, 0)
{:ok, "Hello TCP"}
```

ex-net
```elixir
iex(1)> {:ok, socket} = ExTCP.connect("192.168.1.90", 6789)
{:ok, #Reference<0.3893668254.4126146566.224887>}
iex(2)> flush()
{:tcp, #Reference<0.3893668254.4126146566.224887>, "hello"}
{:tcp, #Reference<0.3893668254.4126146566.224887>, "123"}
:ok
iex(3)> ExTCP.send(socket, "Hello TCP")
:ok
```

## UDP

```elixir
iex(1)> {:ok, socket} = ExUDP.open(8888)
{:ok, #Reference<0.3071399119.740818950.172299>}
iex(2)> ExUDP.send(socket, "192.168.1.90", 9090, "Hello, from ex-net")
:ok
```

## HTTP
```elixir
iex(1)> ExHTTP.get("ifconfig.me")
Remote IP address: 34.160.111.145
{:ok,
 "HTTP/1.1 200 OK\r\nserver: istio-envoy\r\ndate: Fri, 17 Nov 2023 16:13:49 GMT\r\ncontent-type: text/plain\r\nContent-Length:
 13\r\naccess-control-allow-origin: *\r\nx-envoy-upstream-service-time: 0\r\nstrict-transport-security: max-age=2592000; inc
ludeSubDomains\r\nVia: 1.1 google\r\n\r\n123.123.22.33"}
```

## DNS

```elixir
iex(2)> {:ok, ip_addr} = ExDNS.find_ip_address("ifconfig.me")
{:ok, 580939665}
iex(3)> IPv4.ip_addr_to_string(ip_addr)
"34.160.111.145"
```

## ARP
```elixir
iex(1)> {:ok, mac_addr} = ExARP.find_mac_address("192.168.1.1")
{:ok, 64727626581}
iex(2)> ExNet.Core.Ethernet.mac_i2s(mac_addr)
"00:0f:12:11:33:55"
```
