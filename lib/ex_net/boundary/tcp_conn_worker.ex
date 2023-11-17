defmodule ExNet.Boundary.TcpConnWorker do
  use GenServer
  alias ExNet.Core.Tcp
  alias ExNet.Core.TcpSocket
  alias ExNet.Boundary.IpServer

  defmodule State do
    defstruct [
      :socket,
      :tcp_state
    ]
  end

  # API
  def start_tcp_client(socket) do
    DynamicSupervisor.start_child(ExNet.Supervisor.TcpConnSup, {__MODULE__, {:client, socket}})
  end

  def send_with_worker(pid, message) do
    GenServer.cast(pid, {:send, message})
  end

  def recv(pid, tcp_data) do
    GenServer.cast(pid, {:recv, tcp_data})
  end

  # Supervisor Callback
  def child_spec({:client, socket}) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [{:client, socket}]},
      restart: :temporary
    }
  end

  # GenServer
  def start_link({:client, socket}) do
    GenServer.start_link(__MODULE__, {:client, socket})
  end

  @impl GenServer
  def init({:client, socket}) do
    {:ok, %State{socket: socket}, {:continue, :init_syn}}
  end

  @impl GenServer
  def handle_continue(:init_syn, %State{socket: socket} = state) do
    seq_num = Enum.random(0x10_FE_DA_BC..0x7F_FF_FF_FF)
    socket = %TcpSocket{socket | seq_num: seq_num}
    {:ok, new_socket} = init_handshake(socket)
    new_state = %State{state | socket: new_socket, tcp_state: :syn_sent}
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast(
        {:send, data},
        %State{socket: socket, tcp_state: :established} = state
      ) do
    {:ok, new_socket} = send_tcp_data(socket, data)
    {:noreply, %State{state | socket: new_socket}}
  end

  def handle_cast({:recv, tcp_data}, %State{socket: socket, tcp_state: :syn_sent} = state) do
    {:ok, new_socket} = finish_handshake(socket, tcp_data)
    {:noreply, %{state | socket: new_socket, tcp_state: :established}}
  end

  def handle_cast({:recv, %Tcp{data: ""}}, %State{} = state) do
    {:noreply, state}
  end

  def handle_cast({:recv, %Tcp{data: data} = tcp}, %State{socket: socket} = state) do
    if :PSH in tcp.flags do
      # IO.puts(
      #   "收到TCP.seq_num=#{tcp.seq_num} ack_num=#{tcp.ack_num} 我当前的ack_num: #{socket.ack_num}"
      # )

      size = byte_size(data)
      socket = %TcpSocket{socket | ack_num: socket.ack_num + size}
      send_tcp_data(socket, "")
      send(socket.pid, {:tcp, socket.ref, data})
      {:noreply, %State{state | socket: socket}}
    else
      # IO.inspect(tcp, label: "收到不含PSH的TCP数据")
      {:noreply, state}
    end
  end

  # Step 1 of three-way handshake
  defp init_handshake(%TcpSocket{seq_num: seq_num} = socket) do
    tcp_packet =
      Tcp.make_syn_packet(socket.my_ip, socket.my_port, socket.dst_ip, socket.dst_port, seq_num)

    IpServer.send(socket.dst_ip, :TCP, tcp_packet)
    new_socket = %TcpSocket{socket | seq_num: seq_num + 1}
    {:ok, new_socket}
  end

  # Step 3 of three-way handshake
  defp finish_handshake(socket, tcp_data) do
    # 拆解来源数据
    %Tcp{
      # 来源远程，对方的源端口，是我等下要发送的远程端口
      src_port: dst_port,
      dst_port: src_port,
      seq_num: seq_to_ack
    } = tcp_data

    # SYN+1 确认
    ack_num = seq_to_ack + 1

    # 构造发出数据
    out_tcp = %Tcp{
      src_port: src_port,
      dst_port: dst_port,
      seq_num: socket.seq_num,
      ack_num: ack_num,
      flags: [:ACK]
    }

    out_tcp_packet = Tcp.make_tcp_packet(socket.my_ip, socket.dst_ip, out_tcp)
    IpServer.send(socket.dst_ip, :TCP, out_tcp_packet)
    new_socket = %TcpSocket{socket | ack_num: ack_num}
    {:ok, new_socket}
  end

  defp send_tcp_data(%TcpSocket{seq_num: seq_num} = socket, data) do
    out_tcp = %Tcp{
      src_port: socket.my_port,
      dst_port: socket.dst_port,
      seq_num: seq_num,
      # 始终保持发送ACK
      ack_num: socket.ack_num,
      flags: [:PSH, :ACK],
      data: data
    }

    data_size = byte_size(data)
    out_tcp_packet = Tcp.make_tcp_packet(socket.my_ip, socket.dst_ip, out_tcp)
    IpServer.send(socket.dst_ip, :TCP, out_tcp_packet)

    new_socket = %TcpSocket{socket | seq_num: seq_num + data_size}
    {:ok, new_socket}
  end
end
