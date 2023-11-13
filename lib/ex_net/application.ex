defmodule ExNet.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [{ExNet.Boundary.PcapServer, []}]

    opts = [strategy: :one_for_one, name: ExNet.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
