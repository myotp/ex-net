defmodule ExNet.Api.ExHTTP do
  alias ExNet.Api.ExDNS
  alias ExNet.Api.ExTCP
  alias ExNet.Core.IPv4

  def get(host) do
    {:ok, ip_addr} = ExDNS.find_ip_address(host)
    IO.puts("Remote IP address: #{IPv4.ip_addr_to_string(ip_addr)}")
    {:ok, socket} = ExTCP.connect(ip_addr, 80)
    Process.sleep(3000)
    request = http_get_request(host)
    ExTCP.send(socket, request)
    loop_receive(<<>>)
  end

  defp loop_receive(acc) do
    receive do
      {:tcp, _, reply} ->
        loop_receive(<<acc::binary, reply::binary>>)
    after
      2000 ->
        {:ok, acc}
    end
  end

  def http_get_request(host) do
    """
    GET / HTTP/1.1
    Host: #{host}
    Accept: */*

    """
    |> String.split("\n")
    |> Enum.join("\r\n")
  end
end
