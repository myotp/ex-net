defmodule ExNet.Api.Inet do
  alias ExNet.Boundary.ArpServer

  def find_mac_address(ip_address, timeout \\ 5000) do
    ArpServer.find_mac_addr(ip_address, timeout)
  end
end
