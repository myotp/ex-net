defmodule ExNet.Boundary.DnsServer do
  use GenServer
  require Logger
  alias ExNet.Core.IPv4
  alias ExNet.Core.Dns
  alias ExNet.Boundary.Config
  alias ExNet.Api.ExUDP

  @dns_dst_port 53

  defmodule State do
    defstruct ~w[dns_ip_addr dns_cache single_socket debug?]a
  end

  # API
  def find_ip_address(url) do
    GenServer.call(__MODULE__, {:find_ip_address, url})
  end

  # GenServer
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    table = :ets.new(:dns_cache, [:set, :protected, read_concurrency: true])
    dns_ip_addr = Config.dns_ip_address!()
    Logger.info("本机dns_server所用DNS地址: #{dns_ip_addr}")

    {:ok,
     %State{dns_ip_addr: IPv4.ip_addr_to_integer(dns_ip_addr), dns_cache: table, debug?: false}}
  end

  @impl GenServer
  def handle_call({:find_ip_address, url}, from, %State{dns_cache: dns_cache} = state) do
    case :ets.lookup(dns_cache, url) do
      [{^url, ip_addr}] ->
        {:reply, {:ok, ip_addr}, state}

      [] ->
        spawn(fn -> wait_dns_response(from, url, dns_cache, 10) end)
        {:noreply, state, {:continue, {:dns_request, url}}}
    end
  end

  @impl GenServer
  def handle_cast({:debug, true}, state) do
    {:noreply, %State{state | debug?: true}}
  end

  def handle_cast({:debug, false}, state) do
    {:noreply, %State{state | debug?: false}}
  end

  @impl GenServer
  def handle_continue({:dns_request, url}, %State{dns_ip_addr: dns_server_ip} = state) do
    dns_req_packet = Dns.request_ip_packet(url)
    {:ok, socket} = ExUDP.open(Enum.random(1025..60000))
    ExUDP.send(socket, dns_server_ip, @dns_dst_port, dns_req_packet)
    {:noreply, %State{state | single_socket: socket}}
  end

  @impl GenServer
  def handle_info(
        {:udp, _socket, _remote_ip, _remote_port, dns_packet},
        %State{dns_cache: dns_cache, debug?: debug?} = state
      ) do
    case Dns.only_parse_one_query_and_ip_addr_answer(dns_packet) do
      nil ->
        :ok

      %Dns{queries: [query], answers: [answer]} ->
        if debug? do
          IO.puts("更新本地DNS#{query.name} IP 地址: #{IPv4.ip_addr_to_string(answer.addr)}")
        end

        :ets.insert(dns_cache, {query.name, answer.addr})
    end

    {:noreply, state}
  end

  defp wait_dns_response(from, _, _, 0) do
    GenServer.reply(from, {:error, :not_found})
  end

  defp wait_dns_response(from, url, dns_cache, n) do
    case :ets.lookup(dns_cache, url) do
      [{^url, ip_addr}] ->
        GenServer.reply(from, {:ok, ip_addr})

      [] ->
        Process.sleep(1000)
        wait_dns_response(from, url, dns_cache, n - 1)
    end
  end
end
