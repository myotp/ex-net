defmodule ExNet.Boundary.DebugManager do
  alias ExNet.Boundary.PcapServer

  def enable(:pcap) do
    GenServer.cast(PcapServer, {:debug, true})
  end

  def disable(:pcap) do
    GenServer.cast(PcapServer, {:debug, false})
  end
end
