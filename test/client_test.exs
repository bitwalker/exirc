defmodule ExIRC.ClientTest do
  use ExUnit.Case, async: false
  use ExIRC.Commands

  alias ExIRC.Client
  alias ExIRC.SenderInfo

  test "start a client linked to the caller " do
    {:ok, _} = ExIRC.start_link!()
  end

  test "start multiple clients" do
    assert {:ok, pid} = ExIRC.start_client!()
    assert {:ok, pid2} = ExIRC.start_client!()
    assert pid != pid2
  end

  test "client dies if owner process dies" do
    test_pid = self()

    pid =
      spawn_link(fn ->
        assert {:ok, pid} = ExIRC.start_client!()
        send(test_pid, {:client, pid})

        receive do
          :stop -> :ok
        end
      end)

    client_pid =
      receive do
        {:client, pid} -> pid
      end

    assert Process.alive?(client_pid)
    send(pid, :stop)
    :timer.sleep(1)
    refute Process.alive?(client_pid)
  end

  test "login sends event to handler" do
    state = get_state()
    state = %{state | logged_on?: false, channels: []}
    msg = %ExIRC.Message{cmd: @rpl_welcome}
    {:noreply, new_state} = Client.handle_data(msg, state)
    assert new_state.logged_on? == true
    assert_receive :logged_in, 10
  end

  test "login failed with nick in use sends event to handler" do
    state = get_state()
    state = %{state | logged_on?: false}
    msg = %ExIRC.Message{cmd: @err_nick_in_use}
    {:noreply, new_state} = Client.handle_data(msg, state)
    assert new_state.logged_on? == false
    assert_receive {:login_failed, :nick_in_use}, 10
  end

  test "own nick change sends event to handler" do
    state = get_state()
    msg = %ExIRC.Message{nick: state.nick, cmd: "NICK", args: ["new_nick"]}
    {:noreply, new_state} = Client.handle_data(msg, state)
    assert new_state.nick == "new_nick"
    assert_receive {:nick_changed, "new_nick"}, 10
  end

  test "receiving private message sends event to handler" do
    state = get_state()

    msg = %ExIRC.Message{
      nick: "other_user",
      cmd: "PRIVMSG",
      args: [state.nick, "message"],
      host: "host",
      user: "user"
    }

    Client.handle_data(msg, state)
    expected_senderinfo = %SenderInfo{nick: "other_user", host: "host", user: "user"}
    assert_receive {:received, "message", ^expected_senderinfo}, 10
  end

  test "receiving channel message sends event to handler" do
    state = get_state()

    msg = %ExIRC.Message{
      nick: "other_user",
      cmd: "PRIVMSG",
      args: ["#testchannel", "message"],
      host: "host",
      user: "user"
    }

    Client.handle_data(msg, state)
    expected_senderinfo = %SenderInfo{nick: "other_user", host: "host", user: "user"}
    assert_receive {:received, "message", ^expected_senderinfo, "#testchannel"}, 10
  end

  test "receiving channel message with lowercase mention sends events to handler" do
    state = get_state()
    chat_message = "hi #{String.downcase(state.nick)}!"

    msg = %ExIRC.Message{
      nick: "other_user",
      cmd: "PRIVMSG",
      args: ["#testchannel", chat_message],
      host: "host",
      user: "user"
    }

    Client.handle_data(msg, state)
    expected_senderinfo = %SenderInfo{nick: "other_user", host: "host", user: "user"}
    assert_receive {:received, ^chat_message, ^expected_senderinfo, "#testchannel"}, 10
    assert_receive {:mentioned, ^chat_message, ^expected_senderinfo, "#testchannel"}, 10
  end

  test "receiving channel message with uppercase mention sends events to handler" do
    state = get_state()
    chat_message = "hi #{String.upcase(state.nick)}!"

    msg = %ExIRC.Message{
      nick: "other_user",
      cmd: "PRIVMSG",
      args: ["#testchannel", chat_message],
      host: "host",
      user: "user"
    }

    Client.handle_data(msg, state)
    expected_senderinfo = %SenderInfo{nick: "other_user", host: "host", user: "user"}
    assert_receive {:received, ^chat_message, ^expected_senderinfo, "#testchannel"}, 10
    assert_receive {:mentioned, ^chat_message, ^expected_senderinfo, "#testchannel"}, 10
  end

  defp get_state() do
    %ExIRC.Client.ClientState{
      nick: "tester",
      logged_on?: true,
      event_handlers: [{self(), Process.monitor(self())}],
      channels: [get_channel()]
    }
  end

  defp get_channel() do
    %ExIRC.Channels.Channel{
      name: "testchannel",
      topic: "topic",
      users: [],
      modes: '',
      type: ''
    }
  end
end
