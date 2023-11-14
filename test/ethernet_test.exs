defmodule EthernetTest do
  use ExUnit.Case
  alias ExNet.Core.Ethernet
  doctest ExNet.Core.Ethernet

  test "mac address to string" do
    assert "56:18:ca:f9:cb:e9" == Ethernet.mac_i2s(94_664_484_572_137)
  end
end
