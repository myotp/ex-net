defmodule ExNet.Core.TcpSocketsDb do
  alias ExNet.Core.TcpSocket

  def new, do: %{}

  def open_port(db, pid, my_ip, my_port, dst_ip, dst_port) do
    case Map.has_key?(db, my_port) do
      true ->
        {:error, :eaddrinuse}

      false ->
        ref = Kernel.make_ref()
        socket = TcpSocket.new(ref, pid, my_ip, my_port, dst_ip, dst_port)
        {:ok, socket}
    end
  end
end
