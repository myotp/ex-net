defmodule DnsTest do
  use ExUnit.Case
  alias ExNet.Core.IPv4
  alias ExNet.Core.Dns

  test "parse/1" do
    dns_packet =
      <<221, 40, 129, 128, 0, 1, 0, 1, 0, 0, 0, 0, 8, 105, 102, 99, 111, 110, 102, 105, 103, 2,
        109, 101, 0, 0, 1, 0, 1, 192, 12, 0, 1, 0, 1, 0, 0, 1, 15, 0, 4, 34, 160, 111, 145>>

    assert Dns.only_parse_one_query_and_ip_addr_answer(dns_packet) ==
             %Dns{
               tid: 0xDD_28,
               flags: 0x81_80,
               questions: 1,
               answer_RRs: 1,
               authority_RRs: 0,
               additional_RRs: 0,
               queries: [%{name: "ifconfig.me", type: :A, class: :IN}],
               answers: [%{addr: IPv4.ip_addr_to_integer("34.160.111.145")}]
             }
  end
end
