defmodule ExNet.Core.Ethernet do
  defstruct ~w[src dst type data]a

  @mac_addr_digits 12
  @eth_broadcast_mac 0xFFFF_FFFF_FFFF

  @eth_type_ipv4 0x0800
  @eth_type_ipv6 0x86DD
  @eth_type_arp 0x0806

  def broadcast_mac, do: @eth_broadcast_mac

  def new(packet) when is_binary(packet) do
    <<dst::48-big, src::48-big, type::16-big, data::binary>> = packet
    %__MODULE__{src: src, dst: dst, type: type_i2a(type), data: data}
  end

  def make_eth_packet(dst, src, type, data) when is_atom(type) do
    make_eth_packet(dst, src, type_a2i(type), data)
  end

  def make_eth_packet(dst, src, type, data) do
    <<dst::48-big, src::48-big, type::16-big, data::binary>>
  end

  def mac_i2s(mac_addr) do
    mac_addr
    |> Integer.to_string(16)
    |> String.pad_leading(@mac_addr_digits, "0")
    |> pretty()
  end

  defp pretty(s) do
    s
    |> String.to_charlist()
    |> Enum.chunk_every(2)
    |> Enum.join(":")
    |> String.downcase()
  end

  def mac_s2i(s) do
    s
    |> String.replace(":", "")
    |> String.to_integer(16)
  end

  def type_i2a(@eth_type_ipv4), do: :IPv4
  def type_i2a(@eth_type_ipv6), do: :IPv6
  def type_i2a(@eth_type_arp), do: :ARP

  def type_a2i(:ARP), do: @eth_type_arp
  def type_a2i(:IPv4), do: @eth_type_ipv4
  def type_a2i(:IPv6), do: @eth_type_ipv6

  def type_to_string(@eth_type_ipv4), do: "IPv4"
  def type_to_string(@eth_type_ipv6), do: "IPv6"
  def type_to_string(@eth_type_arp), do: "ARP"
  def type_to_string(:IPv4), do: "IPv4"
  def type_to_string(:IPv6), do: "IPv6"
  def type_to_string(:ARP), do: "ARP"
end

defimpl Inspect, for: ExNet.Core.Ethernet do
  alias ExNet.Core.Ethernet

  def inspect(eth, _opts) do
    src = Ethernet.mac_i2s(eth.src)
    dst = Ethernet.mac_i2s(eth.dst)
    "[Eth] #{src} => #{dst} [#{eth.type}]"
  end
end

defimpl String.Chars, for: ExNet.Core.Ethernet do
  def to_string(eth) do
    "#{inspect(eth)}"
  end
end
