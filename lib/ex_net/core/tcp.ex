defmodule ExNet.Core.Tcp do
  import Bitwise
  alias ExNet.Core.IPv4
  alias ExNet.Core.Checksum

  defstruct [
    :src_port,
    :dst_port,
    :seq_num,
    :ack_num,
    :flags,
    checksum: 0,
    data: <<>>,
    options: <<>>,
    window_size: 0xFF_FF,
    urgent_pointer: 0
  ]

  @flags_a2i %{
    :FIN => 1 <<< 0,
    :SYN => 1 <<< 1,
    :RST => 1 <<< 2,
    :PSH => 1 <<< 3,
    :ACK => 1 <<< 4,
    :URG => 1 <<< 5,
    :ECE => 1 <<< 6,
    :CWR => 1 <<< 7,
    :NS => 1 <<< 8
  }

  @flags_i2a Enum.reduce(@flags_a2i, %{}, fn {k, v}, acc -> Map.put(acc, v, k) end)

  def decode(packet) do
    <<src_port::16-big, dst_port::16-big, seq_num::32-big, ack_num::32-big, offset::4, 0::3,
      flag_bits::9, window_size::16, checksum::16, urgent_pointer::16, rest::binary>> = packet

    # offset是用word(4bytes)表示的，除去基本头部5个word之后
    # 剩下x4字节数就是额外options所占字节数
    option_bytes = (offset - 5) * 4

    <<options::binary-size(option_bytes), data::binary>> = rest

    %__MODULE__{
      src_port: src_port,
      dst_port: dst_port,
      seq_num: seq_num,
      ack_num: ack_num,
      flags: decode_flags(flag_bits),
      window_size: window_size,
      checksum: checksum,
      urgent_pointer: urgent_pointer,
      options: decode_options(options),
      data: data
    }
  end

  def make_syn_packet(src_ip, src_port, dst_ip, dst_port, seq_num) do
    make_tcp_packet(src_ip, dst_ip, %__MODULE__{
      src_port: src_port,
      dst_port: dst_port,
      seq_num: seq_num,
      ack_num: 0,
      data: <<>>,
      flags: [:SYN]
    })
  end

  def make_tcp_packet(
        src_ip,
        dst_ip,
        %__MODULE__{
          flags: flags,
          options: options,
          data: data
        } = tcp
      ) do
    flags = encode_flags(flags)
    options = encode_options(options)

    # 用word(=4bytes)表示
    offset = Kernel.div(byte_size(options) + 20, 4)
    total_length_in_bytes = offset * 4 + byte_size(data)
    pseudo_header = make_pseudo_header(src_ip, dst_ip, total_length_in_bytes)
    tcp_packet_0_checksum = do_make_tcp_packet(tcp, flags, options, 0)
    bin_for_checksum = <<pseudo_header::binary, tcp_packet_0_checksum::binary>>
    checksum = Checksum.crc16_checksum(bin_for_checksum)
    do_make_tcp_packet(tcp, flags, options, checksum)
  end

  defp encode_flags(flags) do
    flags
    |> Enum.map(fn flag -> @flags_a2i[flag] end)
    |> Enum.sum()
  end

  defp decode_flags(flags) do
    flags
    |> to_2s()
    |> Enum.map(fn i -> @flags_i2a[i] end)
  end

  defp to_2s(i) do
    to_2s(i, 1, [])
  end

  defp to_2s(0, _, acc), do: acc

  defp to_2s(i, base, acc) do
    case i &&& 1 do
      0 ->
        to_2s(i >>> 1, base * 2, acc)

      1 ->
        to_2s(i >>> 1, base * 2, [base | acc])
    end
  end

  defp encode_options(options) do
    options
  end

  defp decode_options(options) do
    options
  end

  defp do_make_tcp_packet(
         %__MODULE__{
           src_port: src_port,
           dst_port: dst_port,
           seq_num: seq_num,
           ack_num: ack_num,
           window_size: window_size,
           urgent_pointer: urgent_pointer,
           data: data
         },
         flags,
         options,
         checksum
       ) do
    offset = Kernel.div(byte_size(options) + 20, 4)

    <<src_port::16-big, dst_port::16-big, seq_num::32-big, ack_num::32-big, offset::4, 0::3,
      flags::9, window_size::16, checksum::16, urgent_pointer::16, options::binary, data::binary>>
  end

  defp make_pseudo_header(src_ip, dst_ip, length) do
    protocol = IPv4.protocol_a2i(:TCP)

    <<
      src_ip::32-big,
      dst_ip::32-big,
      # 8bits保留0
      0::8,
      protocol::8,
      length::16-big
    >>
  end
end
