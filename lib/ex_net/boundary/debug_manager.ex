defmodule ExNet.Boundary.DebugManager do
  def enable(type) do
    GenServer.cast(type_to_server(type), {:debug, true})
  end

  def disable(type) do
    GenServer.cast(type_to_server(type), {:debug, false})
  end

  defp type_to_server(:pcap), do: ExNet.Boundary.PcapServer
  defp type_to_server(:eth), do: ExNet.Boundary.EthServer
  defp type_to_server(:arp), do: ExNet.Boundary.ArpServer
  defp type_to_server(:ip), do: ExNet.Boundary.IpServer
  defp type_to_server(:udp), do: ExNet.Boundary.UdpServer
end
