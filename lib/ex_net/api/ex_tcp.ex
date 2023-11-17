defmodule ExNet.Api.ExTCP do
  alias ExNet.Boundary.TcpServer

  def connect(dst_ip, dst_port) do
    TcpServer.connect(dst_ip, dst_port)
  end

  def send(socket, bin) do
    TcpServer.send(socket, bin)
  end
end
