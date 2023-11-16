defmodule ExNet.Boundary.UdpServer do
  use GenServer
  require Logger

  alias ExNet.Core.UDP
  alias ExNet.Core.IPv4
  alias ExNew.Core.UdpSocketsDb
  alias ExNet.Boundary.IpServer

  # UDP的checksum需要知道IP
  defmodule State do
    defstruct ~w[ip sockets debug?]a
  end

  # API
  def open(port), do: GenServer.call(__MODULE__, {:open, self(), port})

  def send(socket, dst_ip, dst_port, packet) when is_binary(dst_ip) do
    send(socket, IPv4.ip_addr_to_integer(dst_ip), dst_port, packet)
  end

  def send(socket, dst_ip, dst_port, packet) do
    GenServer.call(__MODULE__, {:send, socket, dst_ip, dst_port, packet})
  end

  def recv({src_ip, data}), do: GenServer.cast(__MODULE__, {:recv, src_ip, data})

  # GenServer
  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    ip = Application.fetch_env!(:ex_net, :virtual_ip_address) |> IPv4.ip_addr_to_integer()
    Logger.info("本机udp_server所用虚拟IP地址: #{ip}")
    sockets = UdpSocketsDb.new()
    {:ok, %State{ip: ip, sockets: sockets, debug?: false}}
  end

  @impl GenServer
  def handle_call({:open, from_pid, port}, _from, %{sockets: m} = state) do
    case UdpSocketsDb.open_port(m, from_pid, port) do
      {:ok, socket, new_sockets} ->
        {:reply, {:ok, socket}, %State{state | sockets: new_sockets}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:send, socket_ref, dst_ip, dst_port, packet}, _from, %{sockets: m} = state) do
    case Map.fetch(m, socket_ref) do
      {:ok, socket} ->
        udp_packet = UDP.make_udp_packet(state.ip, socket.port, dst_ip, dst_port, packet)
        IpServer.send(dst_ip, :UDP, udp_packet)
        {:reply, :ok, state}

      :error ->
        {:reply, :error, state}
    end
  end

  @impl GenServer
  def handle_cast({:recv, src_ip, data}, %State{debug?: debug?} = state) do
    udp = UDP.new(data)

    if debug? do
      IO.puts("#{IPv4.ip_addr_to_string(src_ip)} #{inspect(udp)}")
    end

    # UDP 根据目标端口找到进程，当前只支持active模式
    case Map.fetch(state.sockets, udp.dst_port) do
      {:ok, socket} ->
        udp_msg = {:udp, socket.ref, IPv4.ip_addr_to_tuple(src_ip), udp.src_port, udp.data}
        send(socket.pid, udp_msg)

      _ ->
        nil
    end

    {:noreply, state}
  end

  def handle_cast({:debug, true}, state) do
    {:noreply, %State{state | debug?: true}}
  end

  def handle_cast({:debug, false}, state) do
    {:noreply, %State{state | debug?: false}}
  end
end
