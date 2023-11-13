defmodule ExNet.Boundary.PcapDriver do
  require Logger

  # pcap驱动
  @pointer_size 64
  @snap_len 65535
  @promisc 1
  @pcap_timeout 100
  # 自定义与port端交互的协议
  @pcap_open 1
  @pcap_loop 2
  @pcap_inject 7

  def open(port, iface) do
    Port.command(port, pcap_cmd_open(iface))
    receive do
      {^port, {:data, <<pcap::unsigned-native-integer-size(@pointer_size)>>}} ->
        Logger.info "pcap打开返回结果: #{pcap}"
        case pcap do
          -1 ->
            :error
          _ ->
            {:ok, pcap}
        end
    end
  end

  def loop(port, pcap) do
    Port.command(port, pcap_cmd_loop(pcap))
  end

  def inject(port, pcap, data) do
    Port.command(port, pcap_cmd_inject(pcap, data))
  end

  # == 凑出具体发送给sniff的数据包 ==
  defp pcap_cmd_open(iface) do
    <<@pcap_open::8,
      @snap_len::32-unsigned-native-integer,
      @promisc::8,
      @pcap_timeout::32-unsigned-native-integer,
      String.length(iface)::32-unsigned-native-integer,
      iface::binary>>
  end

  defp pcap_cmd_loop(pcap) do
    <<@pcap_loop::8,
      pcap::unsigned-native-integer-size(@pointer_size)>> # [LEARN] 好多bits操作
  end

  defp pcap_cmd_inject(pcap, data) do
    <<@pcap_inject::8,
      pcap::unsigned-native-integer-size(@pointer_size),
      Kernel.byte_size(data)::32-native-integer,
      data::binary>>
  end
end
