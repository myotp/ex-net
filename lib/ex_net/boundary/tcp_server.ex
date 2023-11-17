defmodule ExNet.Boundary.TcpServer do
  use GenServer
  alias ExNet.Boundary.Config
  alias ExNet.Boundary.TcpConnWorker
  alias ExNet.Core.IPv4
  alias ExNet.Core.Tcp
  alias ExNet.Core.TcpSocket
  alias ExNet.Core.TcpSocketsDb

  defmodule State do
    defstruct ~w[ip_addr connections debug?]a
  end

  # API
  def connect(dst_ip, dst_port) do
    GenServer.call(__MODULE__, {:connect, self(), dst_ip, dst_port})
  end

  def send(socket, bin) do
    GenServer.cast(__MODULE__, {:send, socket, bin})
  end

  def recv(bin) do
    GenServer.cast(__MODULE__, {:recv, bin})
  end

  # GenServer
  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    ip_addr_str = Config.virtual_ip_address!()
    IO.puts("本机TCP所用虚拟IP地址: #{ip_addr_str}")
    ip_addr = IPv4.ip_addr_to_integer(ip_addr_str)
    {:ok, %State{ip_addr: ip_addr, connections: %{}}}
  end

  @impl GenServer
  def handle_call(
        {:connect, from_pid, dst_ip, dst_port},
        _from,
        %State{ip_addr: local_ip, connections: connections} = state
      ) do
    dst_ip = IPv4.ip_addr_to_integer(dst_ip)
    local_port = allocate_port(connections)

    case TcpSocketsDb.open_port(connections, from_pid, local_ip, local_port, dst_ip, dst_port) do
      {:ok, %TcpSocket{ref: ref} = socket} ->
        {:ok, worker_pid} = TcpConnWorker.start_tcp_client(socket)

        new_connections =
          connections
          # 后续本机靠此ref映射到对应的进程
          |> Map.put(ref, worker_pid)
          # 处理接收包，找到指定进程接收
          |> Map.put(local_port, worker_pid)

        {:reply, {:ok, ref}, %State{state | connections: new_connections}}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_cast({:send, socket, bin}, %State{connections: connections} = state) do
    worker_pid = connections[socket]
    TcpConnWorker.send_with_worker(worker_pid, bin)
    {:noreply, state}
  end

  def handle_cast({:recv, bin}, %State{connections: connections, debug?: debug?} = state) do
    tcp = Tcp.decode(bin)

    if debug? do
      IO.inspect(tcp)
    end

    worker_pid = Map.get(connections, tcp.dst_port)

    if worker_pid do
      TcpConnWorker.recv(worker_pid, tcp)
    end

    {:noreply, state}
  end

  def handle_cast({:debug, true}, state) do
    {:noreply, %State{state | debug?: true}}
  end

  def handle_cast({:debug, false}, state) do
    {:noreply, %State{state | debug?: false}}
  end

  # 需要考虑已经占用port的情况
  defp allocate_port(_) do
    Enum.random(50050..61000)
  end
end
