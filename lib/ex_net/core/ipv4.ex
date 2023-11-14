defmodule ExNet.Core.IPv4 do
  import Bitwise
  alias ExNet.Core.Checksum

  @ip_version 4
  @ip_min_header_length 5
  #  @ip_flag_reservred 0b100

  @ip_flag_one_packet 0
  @ip_flag_more_fragments 1
  @ip_flag_do_not_fragment 2
  #  @ip_flag_last_fragment 0
  @ip_ttl 64
  @ip_checksum_empty 0

  defstruct ~w[id src_ip dst_ip protocol fragment? data]a

  def new(packet) do
    <<@ip_version::4, _header_length?::4, _flag?::8, _size::16, id::16, fragment?::3,
      _whatisthis?::13, _ttl::8, protocol::8, _checksum::16, src_ip::32, dst_ip::32,
      data::binary>> = packet

    %__MODULE__{
      id: id,
      src_ip: src_ip,
      dst_ip: dst_ip,
      protocol: protocol_i2a(protocol),
      fragment?: fragment_i2a(fragment?),
      data: data
    }
  end

  def make_ipv4_packet(id, src_ip, dst_ip, protocol, data) do
    data_size = byte_size(data)
    header = make_ipv4_header(id, src_ip, dst_ip, protocol, data_size)
    <<header::binary, data::binary>>
  end

  def make_ipv4_header(id, src_ip, dst_ip, protocol, data_size) do
    ip_packet_total_size = data_size + @ip_min_header_length * 4

    header0 =
      <<@ip_version::4, @ip_min_header_length::4, 0::8, ip_packet_total_size::16, id::16,
        @ip_flag_one_packet::3, 0::13, @ip_ttl::8, protocol_a2i(protocol)::8,
        @ip_checksum_empty::16, src_ip::32, dst_ip::32>>

    checksum = Checksum.crc16_checksum(header0)

    <<@ip_version::4, @ip_min_header_length::4, 0::8, ip_packet_total_size::16, id::16,
      @ip_flag_one_packet::3, 0::13, @ip_ttl::8, protocol_a2i(protocol)::8, checksum::16,
      src_ip::32, dst_ip::32>>
  end

  defp fragment_i2a(@ip_flag_one_packet), do: "ONE/LAST"
  defp fragment_i2a(@ip_flag_more_fragments), do: "MORE"
  defp fragment_i2a(@ip_flag_do_not_fragment), do: "DO NOT"

  def protocol_a2i(:TCP), do: 0x06
  def protocol_a2i(:UDP), do: 0x11

  def protocol_i2a(0x06), do: :TCP
  def protocol_i2a(0x11), do: :UDP

  def ip_addr_to_tuple(i) when is_integer(i) do
    ip_addr_i2t(i, [])
  end

  def ip_addr_to_tuple(s) when is_binary(s) do
    case :inet_parse.address(String.to_charlist(s)) do
      {:ok, t} ->
        t

      {:error, _reason} ->
        nil
    end
  end

  def ip_addr_to_integer(i) when is_integer(i), do: i

  def ip_addr_to_integer({a, b, c, d}) do
    (a <<< 24) + (b <<< 16) + (c <<< 8) + d
  end

  def ip_addr_to_integer(s) when is_binary(s) do
    s
    |> ip_addr_to_tuple()
    |> ip_addr_to_integer()
  end

  def ip_addr_to_string(t) when is_tuple(t) do
    :inet_parse.ntoa(t) |> List.to_string()
  end

  def ip_addr_to_string(i) when is_integer(i) do
    i
    |> ip_addr_to_tuple()
    |> ip_addr_to_string()
  end

  defp ip_addr_i2t(i, acc) when i <= 0xFF do
    List.to_tuple([i | acc])
  end

  defp ip_addr_i2t(i, acc) do
    x = i &&& 0xFF
    y = i >>> 8
    ip_addr_i2t(y, [x | acc])
  end
end

defimpl Inspect, for: ExNet.Core.IPv4 do
  alias ExNet.Core.IPv4

  def inspect(ip, _opts) do
    src_ip = IPv4.ip_addr_to_string(ip.src_ip)
    dst_ip = IPv4.ip_addr_to_string(ip.dst_ip)
    "[IPv4] #{src_ip} => #{dst_ip} [#{ip.id}] [#{ip.protocol}] [#{ip.fragment?}]"
  end
end

defimpl String.Chars, for: ExNet.Core.IPv4 do
  def to_string(ip) do
    "#{inspect(ip)}"
  end
end
