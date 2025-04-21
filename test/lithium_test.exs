defmodule LithiumTest do
  use ExUnit.Case
  doctest Lithium

  test "greets the world" do
    assert Lithium.hello() == :world
  end
end
