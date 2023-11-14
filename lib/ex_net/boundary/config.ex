defmodule ExNet.Boundary.Config do
  def device_name!() do
    Application.fetch_env!(:ex_net, :device_name)
  end
end
