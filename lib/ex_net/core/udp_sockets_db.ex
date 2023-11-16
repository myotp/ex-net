defmodule ExNew.Core.UdpSocketsDb do
  alias ExNet.Core.UdpSocket

  def new, do: %{}

  def open_port(db, pid, port) do
    case Map.has_key?(db, port) do
      true ->
        {:error, :eaddrinuse}

      false ->
        ref = Kernel.make_ref()
        socket = UdpSocket.new(ref, pid, port)

        new_db =
          db
          |> Map.put(ref, socket)
          |> Map.put(pid, socket)
          |> Map.put(port, socket)

        {:ok, ref, new_db}
    end
  end
end
