defmodule ExNet.Boundary.EthServer do
  use GenServer
  import Bitwise
  require Logger

  alias ExNet.Boundary.PcapServer
  alias ExNet.Boundary.Config
  alias ExNet.Core.Ethernet

  defmodule State do
    defstruct ~w[local_mac_addr debug?]a
  end

  # API
  def local_mac_addr, do: GenServer.call(__MODULE__, :local_mac_addr)
  def recv(data), do: GenServer.cast(__MODULE__, {:recv, data})

  def send(dst_mac, type, packet) do
    GenServer.cast(__MODULE__, {:send, dst_mac, type, packet})
  end

  def start_link(_args) do
    mac_addr = fetch_local_mac_addr!()
    Logger.info("本机MAC地址为: #{ExNet.Core.Ethernet.mac_i2s(mac_addr)}")
    GenServer.start_link(__MODULE__, %{local_mac_addr: mac_addr}, name: __MODULE__)
  end

  @impl GenServer
  def init(%{local_mac_addr: local_mac_addr}) do
    {:ok, %State{local_mac_addr: local_mac_addr, debug?: false}}
  end

  @impl GenServer
  def handle_call(:local_mac_addr, _from, %State{local_mac_addr: addr} = state) do
    {:reply, Ethernet.mac_i2s(addr), state}
  end

  @impl GenServer
  # === 接收数据包 ===
  def handle_cast({:recv, packet}, %State{debug?: debug?} = state) do
    eth = Ethernet.new(packet)

    if debug? do
      IO.inspect(eth)
    end

    handle_packet(state.local_mac_addr, eth)
    {:noreply, state}
  end

  def handle_cast({:send, dst_mac, eth_type, packet}, state) do
    do_send_eth_packet(dst_mac, state.local_mac_addr, eth_type, packet)
    {:noreply, state}
  end

  def handle_cast({:debug, true}, state) do
    {:noreply, %State{state | debug?: true}}
  end

  def handle_cast({:debug, false}, state) do
    {:noreply, %State{state | debug?: false}}
  end

  defp fetch_local_mac_addr!() do
    {:ok, addrs} = :inet.getifaddrs()
    {_, addrs} = List.keyfind(addrs, String.to_charlist(Config.device_name!()), 0)
    hwaddr = Keyword.get(addrs, :hwaddr)
    <<mac_addr::big-48>> = :binary.list_to_bin(hwaddr)
    mac_addr
  end

  defp handle_packet(local_mac_addr, eth) do
    if my_packet?(local_mac_addr, eth.dst) do
      case eth.type do
        type ->
          IO.inspect(type, label: "ETH类型")
      end
    end
  end

  defp do_send_eth_packet(dst_mac, src_mac, eth_type, data) do
    packet = Ethernet.make_eth_packet(dst_mac, src_mac, eth_type, data)
    PcapServer.send(packet)
  end

  defp my_packet?(local_mac_addr, dst) do
    (local_mac_addr &&& dst) == local_mac_addr
  end
end
