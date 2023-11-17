defmodule ExNet.Boundary.IpServer do
  use GenServer
  require Logger

  alias ExNet.Boundary.Config
  alias ExNet.Boundary.EthServer
  alias ExNet.Boundary.ArpServer
  alias ExNet.Boundary.UdpServer
  alias ExNet.Boundary.TcpServer
  alias ExNet.Core.Ethernet
  alias ExNet.Core.IPv4

  @default_mtu 1400
  @max_ip_id 0xFFFF_FFFF

  defmodule State do
    defstruct ~w[ip mac mtu id debug?]a
  end

  # API
  def send(dst_ip, protocol, data) when is_binary(dst_ip) do
    send(IPv4.ip_addr_to_integer(dst_ip), protocol, data)
  end

  def send(dst_ip, protocol, data) do
    GenServer.cast(__MODULE__, {:send, dst_ip, protocol, data})
  end

  def recv(data), do: GenServer.cast(__MODULE__, {:recv, data})

  # GenServer
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    local_mac_addr = Config.fetch_local_mac_addr!()
    Logger.info("本机ip_server所用MAC地址: #{Ethernet.mac_i2s(local_mac_addr)}")
    ip_addr = Application.fetch_env!(:ex_net, :virtual_ip_address)
    Logger.info("本机ip_server所用虚拟IP地址: #{ip_addr}")

    {:ok,
     %State{
       mac: local_mac_addr,
       ip: IPv4.ip_addr_to_integer(ip_addr),
       id: Enum.random(1..@max_ip_id),
       debug?: false,
       mtu: @default_mtu
     }}
  end

  defp next_id(id) do
    Integer.mod(id + 1, @max_ip_id)
  end

  @impl GenServer
  def handle_cast({:send, dst_ip, protocol, data}, %{id: id} = state) do
    case byte_size(data) < state.mtu do
      # 暂时只考虑单包小包情况
      true ->
        send_single_packet(id, state.ip, dst_ip, protocol, data)
    end

    {:noreply, %State{state | id: next_id(id)}}
  end

  def handle_cast({:recv, data}, %State{debug?: debug?} = state) do
    ip = IPv4.new(data)

    if debug? do
      IO.inspect(ip)
    end

    handle_packet(state, ip)
    {:noreply, state}
  end

  def handle_cast({:debug, true}, state) do
    {:noreply, %State{state | debug?: true}}
  end

  def handle_cast({:debug, false}, state) do
    {:noreply, %State{state | debug?: false}}
  end

  defp handle_packet(state, ip) do
    if state.ip == ip.dst_ip do
      case ip.protocol do
        :UDP ->
          UdpServer.recv({ip.src_ip, ip.data})

        :TCP ->
          TcpServer.recv(ip.data)

        _ ->
          :ok
      end
    end
  end

  defp send_single_packet(id, src_ip, dst_ip, protocol, data) do
    ip_packet = IPv4.make_ipv4_packet(id, src_ip, dst_ip, protocol, data)

    case ArpServer.find_mac_addr(dst_ip, 500) do
      {:ok, dst_mac} ->
        EthServer.send(dst_mac, :IPv4, ip_packet)

      _ ->
        {:ok, gateway_mac} = ArpServer.find_mac_addr(Config.gateway_ip_address!(), 500)
        EthServer.send(gateway_mac, :IPv4, ip_packet)
    end
  end
end
