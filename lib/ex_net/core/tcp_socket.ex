defmodule ExNet.Core.TcpSocket do
  defstruct ~w[ref pid my_ip my_port dst_ip dst_port seq_num ack_num]a

  def new(ref, pid, my_ip, my_port, dst_ip, dst_port) do
    %__MODULE__{
      ref: ref,
      pid: pid,
      my_ip: my_ip,
      my_port: my_port,
      dst_ip: dst_ip,
      dst_port: dst_port,
      seq_num: 0,
      ack_num: 0
    }
  end
end
