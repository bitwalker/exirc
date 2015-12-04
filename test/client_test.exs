defmodule ExIrc.ClientTest do
  use ExUnit.Case


  test "start multiple clients" do
    {:ok, pid} = ExIrc.start_client!
    {:ok, pid2} = ExIrc.start_client!
    assert pid != pid2
  end

end
