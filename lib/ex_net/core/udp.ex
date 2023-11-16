defmodule ExNet.Core.UDP do
  alias ExNet.Core.IPv4
  alias ExNet.Core.Checksum

  defstruct ~w[src_port dst_port length data]a

  def new(packet) do
    <<src_port::16-big, dst_port::16-big,
      length::16-big, _checksum::16-big,
      data::binary>> = packet
    %__MODULE__{src_port: src_port,
                dst_port: dst_port,
                length: length,
                data: data}
  end

  def make_udp_packet(src_ip, src_port, dst_ip, dst_port, data) do
    pseudo_header = make_udp_pseudo_header(src_ip, src_port, dst_ip, dst_port, data)
    checksum = Checksum.crc16_checksum(pseudo_header)
    length = 8 + byte_size(data)
    <<src_port::16-big, dst_port::16-big,
      length::16-big, checksum::16-big,
      data::binary>>
  end

  defp make_udp_pseudo_header(src_ip, src_port, dst_ip, dst_port, data) do
    total_size = 8 + byte_size(data)
    <<src_ip::32-big,
      dst_ip::32-big,
      0::8, IPv4.protocol_a2i(:UDP)::8, total_size::16-big,
      src_port::16-big, dst_port::16-big,
      total_size::16-big, 0::16-big,
      data::binary>>
  end
end

defimpl Inspect, for: ExNet.Core.UDP do
  def inspect(udp, _opts) do
    "[UDP] #{udp.src_port} => #{udp.dst_port} [#{udp.length}] [#{inspect(udp.data)}]"
  end
end

defimpl String.Chars, for: ExNet.Core.UDP do
  def to_string(udp) do
    "#{inspect udp}"
  end
end
