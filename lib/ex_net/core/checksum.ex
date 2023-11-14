defmodule ExNet.Core.Checksum do
  import Bitwise

  def crc16_checksum(data) when is_binary(data) do
    crc16_checksum(:binary.bin_to_list(data))
  end

  def crc16_checksum(data) do
    data
    |> crc()
    |> Bitwise.bxor(0xFF_FF)
  end

  def crc(data) do
    crc(data, 0)
  end

  def crc([], acc), do: acc

  def crc([a, b | t], acc) do
    # [LEARN] 这里开始优先级搞错了，大错特错
    sum = (a <<< 8) + b
    crc(t, handle_overflow(acc + sum))
  end

  def crc([a], acc) do
    sum = a <<< 8

    (acc + sum)
    |> handle_overflow()
  end

  def handle_overflow(x) when x >= 0 and x <= 0xFFFF, do: x

  def handle_overflow(x) do
    # div(x, 0x1_00_00)
    a = x >>> 16
    # rem(x, 0x1_00_00)
    b = x &&& 0xFFFF
    handle_overflow(a + b)
  end
end
