defmodule ExNet.Boundary.Config do
  def device_name!() do
    Application.fetch_env!(:ex_net, :device_name)
  end

  def virtual_ip_address!() do
    Application.fetch_env!(:ex_net, :virtual_ip_address)
  end

  def gateway_ip_address!() do
    Application.fetch_env!(:ex_net, :gateway_ip_address)
  end

  def dns_ip_address!() do
    Application.fetch_env!(:ex_net, :dns_ip_address)
  end

  def fetch_local_mac_addr!() do
    {:ok, addrs} = :inet.getifaddrs()
    {_, addrs} = List.keyfind(addrs, String.to_charlist(device_name!()), 0)
    hwaddr = Keyword.get(addrs, :hwaddr)
    <<mac_addr::big-48>> = :binary.list_to_bin(hwaddr)
    mac_addr
  end
end
