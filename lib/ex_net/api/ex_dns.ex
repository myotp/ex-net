defmodule ExNet.Api.ExDNS do
  alias ExNet.Boundary.DnsServer

  def find_ip_address(dns_name) do
    DnsServer.find_ip_address(dns_name)
  end
end
