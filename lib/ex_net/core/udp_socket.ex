defmodule ExNet.Core.UdpSocket do
  defstruct ~w[ref pid port]a

  def new(ref, pid, port) do
    %__MODULE__{ref: ref, pid: pid, port: port}
  end
end
