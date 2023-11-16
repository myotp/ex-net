defmodule ExNet.Boundary.ArpServer do
  use GenServer
  require Logger
  import Bitwise

  alias ExNet.Boundary.Config
  alias ExNet.Boundary.EthServer
  alias ExNet.Core.ARP
  alias ExNet.Core.IPv4
  alias ExNet.Core.Ethernet

  @arp_retry_interval 100

  defmodule State do
    defstruct ~w[ip mac arp_cache debug?]a
  end

  # API
  def recv(data), do: GenServer.cast(__MODULE__, {:recv, data})

  def find_mac_addr(ip_addr, timeout) when is_binary(ip_addr) do
    find_mac_addr(IPv4.ip_addr_to_integer(ip_addr), timeout)
  end

  def find_mac_addr(ip_addr, timeout) when is_integer(ip_addr) do
    GenServer.call(__MODULE__, {:find_mac_addr, ip_addr, timeout}, :infinity)
  end

  # GenServer
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    table = :ets.new(:arp_cache, [:set, :protected, read_concurrency: true])
    local_mac_addr = Config.fetch_local_mac_addr!()
    Logger.info("本机arp_server所用MAC地址: #{Ethernet.mac_i2s(local_mac_addr)}")
    ip_addr = Application.fetch_env!(:ex_net, :virtual_ip_address)
    Logger.info("本机arp_server所用虚拟IP地址: #{ip_addr}")

    {:ok,
     %State{
       mac: local_mac_addr,
       ip: IPv4.ip_addr_to_integer(ip_addr),
       arp_cache: table,
       debug?: false
     }}
  end

  @impl GenServer
  def handle_call({:find_mac_addr, ip_addr, timeout}, from, %State{arp_cache: arp_cache} = state) do
    case :ets.lookup(arp_cache, ip_addr) do
      [{^ip_addr, mac_addr}] ->
        {:reply, {:ok, mac_addr}, state}

      [] ->
        spawn(fn -> init_arp_request(from, state, ip_addr, timeout) end)
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:recv, packet}, %State{debug?: debug?} = state) do
    arp = ARP.new(packet)

    if debug? && packet_to_me?(state, arp) do
      IO.inspect(arp)
    end

    handle_packet(state, arp)
    {:noreply, state}
  end

  def handle_cast({:debug, true}, state) do
    {:noreply, %State{state | debug?: true}}
  end

  def handle_cast({:debug, false}, state) do
    {:noreply, %State{state | debug?: false}}
  end

  defp handle_packet(state, arp) do
    if arp.type == :reply and arp.dst_mac == state.mac do
      :ets.insert(state.arp_cache, {arp.src_ip, arp.src_mac})
    end
  end

  defp packet_to_me?(state, arp) do
    # [BUG] 开始写成0xFF_FF_FF_1 就错了。。。
    router_ip = state.ip &&& 0xFF_FF_FF_01

    arp.src_mac == state.mac or
      arp.dst_mac == state.mac or
      (arp.dst_mac == 0 and arp.src_ip != router_ip) or
      (arp.dst_mac == ARP.broadcast_mac() and arp.src_ip != router_ip)
  end

  # [TODO] 这里，现在简单起见，直接反复读取ETS表获得结果，之后改为subscriber通知模式
  defp init_arp_request(from, state, dst_ip, timeout) do
    dst_ip = IPv4.ip_addr_to_integer(dst_ip)
    packet = ARP.request_mac_packet(state.ip, state.mac, dst_ip)
    EthServer.send(Ethernet.broadcast_mac(), :ARP, packet)
    wait_arp_response(from, state.arp_cache, dst_ip, timeout)
  end

  defp wait_arp_response(from, _, _, timeout) when timeout < 0 do
    GenServer.reply(from, {:error, :not_found})
  end

  defp wait_arp_response(from, arp_cache, dst_ip, timeout) do
    case :ets.lookup(arp_cache, dst_ip) do
      [{^dst_ip, dst_mac}] ->
        GenServer.reply(from, {:ok, dst_mac})

      _ ->
        Process.sleep(@arp_retry_interval)
        wait_arp_response(from, arp_cache, dst_ip, timeout - @arp_retry_interval)
    end
  end
end
