defmodule ExNet.Api.ExUDP do
  alias ExNet.Boundary.UdpServer

  def open(port) do
    UdpServer.open(port)
  end

  def send(socket, dst_ip, dst_port, packet) do
    UdpServer.send(socket, dst_ip, dst_port, packet)
  end
end
