defmodule ExNet.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {ExNet.Boundary.DnsServer, []},
      {ExNet.Boundary.UdpServer, []},
      {ExNet.Boundary.IpServer, []},
      {ExNet.Boundary.ArpServer, []},
      {ExNet.Boundary.EthServer, []},
      {ExNet.Boundary.PcapServer, []}
    ]

    opts = [strategy: :one_for_one, name: ExNet.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
