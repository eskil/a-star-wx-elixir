defmodule AstarWxTest do
  use ExUnit.Case
  doctest AstarWx

  test "greets the world" do
    assert AstarWx.hello() == :world
  end
end
