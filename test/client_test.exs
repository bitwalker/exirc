defmodule ExIRC.ClientTest do
  use ExUnit.Case

  test "start multiple clients" do
    assert {:ok, pid} = ExIRC.start_client!
    assert {:ok, pid2} = ExIRC.start_client!
    assert pid != pid2
  end

  test "client dies if owner process dies" do
    test_pid = self()

    pid = spawn_link(fn ->
      assert {:ok, pid} = ExIRC.start_client!
      send(test_pid, {:client, pid})
      receive do
        :stop -> :ok
      end
    end)

    client_pid = receive do
      {:client, pid} -> pid
    end

    assert Process.alive?(client_pid)
    send(pid, :stop)
    :timer.sleep(1)
    refute Process.alive?(client_pid)
  end
end
