defmodule ExNetTest do
  use ExUnit.Case
  doctest ExNet

  test "greets the world" do
    assert ExNet.hello() == :world
  end
end
