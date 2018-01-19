defmodule ExIRC.CommandsTest do
  use ExUnit.Case, async: true

  use ExIRC.Commands

  test "Commands are formatted properly" do
    expected = <<0o001, "TESTCMD", 0o001, ?\r, ?\n>>
    assert expected == ctcp!("TESTCMD") |> IO.iodata_to_binary
    expected = <<"PRIVMSG #testchan :", 0o001, "ACTION mind explodes!!", 0o001, ?\r, ?\n>>
    assert expected == me!("#testchan", "mind explodes!!") |> IO.iodata_to_binary
    expected = <<"PASS testpass", ?\r, ?\n>>
    assert expected == pass!("testpass") |> IO.iodata_to_binary
    expected = <<"NICK testnick", ?\r, ?\n>>
    assert expected == nick!("testnick") |> IO.iodata_to_binary
    expected = <<"USER testuser 0 * :Test User", ?\r, ?\n>>
    assert expected == user!("testuser", "Test User") |> IO.iodata_to_binary
    expected = <<"PONG testnick", ?\r, ?\n>>
    assert expected == pong1!("testnick") |> IO.iodata_to_binary
    expected = <<"PONG testnick othernick", ?\r, ?\n>>
    assert expected == pong2!("testnick", "othernick") |> IO.iodata_to_binary
    expected = <<"PRIVMSG testnick :Test message!", ?\r, ?\n>>
    assert expected == privmsg!("testnick", "Test message!") |> IO.iodata_to_binary
    expected = <<"NOTICE testnick :Test notice!", ?\r, ?\n>>
    assert expected == notice!("testnick", "Test notice!") |> IO.iodata_to_binary
    expected = <<"JOIN testchan", ?\r, ?\n>>
    assert expected == join!("testchan") |> IO.iodata_to_binary
    expected = <<"JOIN testchan chanpass", ?\r, ?\n>>
    assert expected == join!("testchan", "chanpass") |> IO.iodata_to_binary
    expected = <<"PART testchan", ?\r, ?\n>>
    assert expected == part!("testchan") |> IO.iodata_to_binary
    expected = <<"QUIT :Leaving", ?\r, ?\n>>
    assert expected == quit!() |> IO.iodata_to_binary
    expected = <<"QUIT :Goodbye, cruel world.", ?\r, ?\n>>
    assert expected == quit!("Goodbye, cruel world.") |> IO.iodata_to_binary
    expected = <<"KICK #testchan testuser", ?\r, ?\n>>
    assert expected == kick!("#testchan", "testuser") |> IO.iodata_to_binary
    expected = <<"KICK #testchan testuser Get outta here!", ?\r, ?\n>>
    assert expected == kick!("#testchan", "testuser", "Get outta here!") |> IO.iodata_to_binary
    expected = <<"MODE testuser -o", ?\r, ?\n>>
    assert expected == mode!("testuser", "-o") |> IO.iodata_to_binary
    expected = <<"MODE #testchan +im", ?\r, ?\n>>
    assert expected == mode!("#testchan", "+im") |> IO.iodata_to_binary
    expected = <<"MODE #testchan +o testuser", ?\r, ?\n>>
    assert expected == mode!("#testchan", "+o", "testuser") |> IO.iodata_to_binary
    expected = <<"INVITE testuser #testchan", ?\r, ?\n>>
    assert expected == invite!("testuser", "#testchan") |> IO.iodata_to_binary
  end
end
