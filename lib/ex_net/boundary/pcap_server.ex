defmodule ExNet.Boundary.PcapServer do
  use GenServer

  require Logger
  alias ExNet.Boundary.PcapDriver

  defmodule State do
    defstruct ~w[port pcap debug?]a
  end

  # API
  def send!(packet), do: GenServer.cast(__MODULE__, {:send, packet})

  def start_link(args \\ []) do
    Logger.debug("启动pcap...")
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    exec = sniff_path()
    port = Port.open({:spawn, exec}, [{:packet, 2}, :nouse_stdio, :binary])
    {:ok, pcap} = PcapDriver.open(port, device_name!())
    PcapDriver.loop(port, pcap)
    {:ok, %State{port: port, pcap: pcap, debug?: false}}
  end

  @impl GenServer
  def handle_cast({:send, data}, state) do
    PcapDriver.inject(state.port, state.pcap, data)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({_port, {:data, data}}, state) do
    IO.inspect(data, label: "Pcap server received data")
    {:noreply, state}
  end

  defp sniff_path() do
    :code.priv_dir(:ex_net) ++ ~c"/sniff"
  end

  defp device_name!() do
    Application.fetch_env!(:ex_net, :device_name)
  end
end
