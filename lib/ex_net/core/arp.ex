defmodule ExNet.Core.ARP do
  @eth_type_ip 0x0800
  @length_eth_addr 6
  @length_ip_addr 4
  @arp_type_request 1
  @arp_type_reply 2

  defstruct ~w[src_mac src_ip dst_mac dst_ip type]a

  def new(data) do
    <<1::16-big, @eth_type_ip::16-big, @length_eth_addr::8, @length_ip_addr::8, type::16-big,
      src_mac::48-big, src_ip::32-big, dst_mac::48-big, dst_ip::32-big, _::binary>> = data

    %__MODULE__{
      src_mac: src_mac,
      src_ip: src_ip,
      dst_mac: dst_mac,
      dst_ip: dst_ip,
      type: type_i2a(type)
    }
  end

  # 构造请求IP地址ARP包，目标MAC设为0
  def request_mac_packet(src_ip, src_mac, dst_ip) do
    make_arp_packet(@arp_type_request, src_ip, src_mac, dst_ip, 0)
  end

  defp make_arp_packet(type, src_ip, src_mac, dst_ip, dst_mac) do
    <<1::16-big, @eth_type_ip::16-big, @length_eth_addr::8, @length_ip_addr::8, type::16-big,
      src_mac::48-big, src_ip::32-big, dst_mac::48-big, dst_ip::32-big>>
  end

  def broadcast_mac, do: 0xFFFF_FFFF_FFFF

  defp type_i2a(@arp_type_request), do: :request
  defp type_i2a(@arp_type_reply), do: :reply

  defimpl Inspect, for: ExNet.Core.ARP do
    alias ExNet.Core.IPv4
    alias ExNet.Core.Ethernet

    def inspect(arp, _opts) do
      src_ip = IPv4.ip_addr_to_string(arp.src_ip)
      dst_ip = IPv4.ip_addr_to_string(arp.dst_ip)
      src_mac = Ethernet.mac_i2s(arp.src_mac)
      dst_mac = Ethernet.mac_i2s(arp.dst_mac)
      type = String.pad_leading("#{arp.type}", 7, " ")
      "[ARP] #{src_ip} => #{dst_ip} [#{type}] #{src_mac} => #{dst_mac}"
    end
  end

  defimpl String.Chars, for: ExNet.Core.ARP do
    def to_string(arp) do
      "#{inspect(arp)}"
    end
  end
end
