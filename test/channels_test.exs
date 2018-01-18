defmodule ExIRC.ChannelsTest do
  use ExUnit.Case, async: true

  alias ExIRC.Channels, as: Channels

  test "Joining a channel adds it to the tree of currently joined channels" do
    channels = Channels.init() |> Channels.join("#testchannel") |> Channels.channels
    assert Enum.member?(channels, "#testchannel")
  end

  test "The channel name is downcased when joining" do
    channels = Channels.init() |> Channels.join("#TestChannel") |> Channels.channels
    assert Enum.member?(channels, "#testchannel")
  end

  test "Joining the same channel twice is a noop" do
    channels = Channels.init() |> Channels.join("#TestChannel") |> Channels.join("#testchannel") |> Channels.channels
    assert 1 == Enum.count(channels)
  end

  test "Parting a channel removes it from the tree of currently joined channels" do
    tree = Channels.init() |> Channels.join("#testchannel")
    assert Enum.member?(Channels.channels(tree), "#testchannel")
    tree = Channels.part(tree, "#testchannel")
    refute Enum.member?(Channels.channels(tree), "#testchannel")
  end

  test "Parting a channel not in the tree is a noop" do
    tree = Channels.init()
    {count, _} = Channels.part(tree, "#testchannel")
    assert 0 == count
  end

  test "Can set the topic for a channel" do
    channels = Channels.init() |> Channels.join("#testchannel") |> Channels.set_topic("#testchannel", "Welcome to Test Channel!")
    assert "Welcome to Test Channel!" == Channels.channel_topic(channels, "#testchannel")
  end

  test "Setting the topic for a channel we haven't joined returns :error" do
    channels = Channels.init() |> Channels.set_topic("#testchannel", "Welcome to Test Channel!")
    assert {:error, :no_such_channel} == Channels.channel_topic(channels, "#testchannel")
  end

  test "Can set the channel type" do
    channels = Channels.init() |> Channels.join("#testchannel") |> Channels.set_type("#testchannel", "@")
    assert :secret == Channels.channel_type(channels, "#testchannel")
    channels = Channels.set_type(channels, "#testchannel", "*")
    assert :private == Channels.channel_type(channels, "#testchannel")
    channels = Channels.set_type(channels, "#testchannel", "=")
    assert :public == Channels.channel_type(channels, "#testchannel")
  end

  test "Setting the channel type for a channel we haven't joined returns :error" do
    channels = Channels.init() |> Channels.set_type("#testchannel", "@")
    assert {:error, :no_such_channel} == Channels.channel_type(channels, "#testchannel")
  end

  test "Setting an invalid channel type raises CaseClauseError" do
    assert_raise CaseClauseError, "no case clause matching: '!'", fn ->
        Channels.init() |> Channels.join("#testchannel") |> Channels.set_type("#testchannel", "!")
    end
  end

  test "Can join a user to a channel" do
    channels = Channels.init() |> Channels.join("#testchannel") |> Channels.user_join("#testchannel", "testnick")
    assert Channels.channel_has_user?(channels, "#testchannel", "testnick")
  end

  test "Can join multiple users to a channel" do
    channels = Channels.init() |> Channels.join("#testchannel") |> Channels.users_join("#testchannel", ["testnick", "anothernick"])
    assert Channels.channel_has_user?(channels, "#testchannel", "testnick")
    assert Channels.channel_has_user?(channels, "#testchannel", "anothernick")
  end

  test "Strips rank designations from nicks" do
    channels = Channels.init() |> Channels.join("#testchannel") |> Channels.users_join("#testchannel", ["+testnick", "@anothernick", "&athirdnick", "%somanynicks", "~onemorenick"])
    assert Channels.channel_has_user?(channels, "#testchannel", "testnick")
    assert Channels.channel_has_user?(channels, "#testchannel", "anothernick")
    assert Channels.channel_has_user?(channels, "#testchannel", "athirdnick")
    assert Channels.channel_has_user?(channels, "#testchannel", "somanynicks")
    assert Channels.channel_has_user?(channels, "#testchannel", "onemorenick")
  end

  test "Joining a users to a channel we aren't in is a noop" do
    channels = Channels.init() |> Channels.user_join("#testchannel", "testnick")
    assert {:error, :no_such_channel} == Channels.channel_has_user?(channels, "#testchannel", "testnick")
    channels = Channels.init() |> Channels.users_join("#testchannel", ["testnick", "anothernick"])
    assert {:error, :no_such_channel} == Channels.channel_has_user?(channels, "#testchannel", "testnick")
  end

  test "Can part a user from a channel" do
    channels = Channels.init() |> Channels.join("#testchannel") |> Channels.user_join("#testchannel", "testnick")
    assert Channels.channel_has_user?(channels, "#testchannel", "testnick")
    channels = channels |> Channels.user_part("#testchannel", "testnick")
    refute Channels.channel_has_user?(channels, "#testchannel", "testnick")
  end

  test "Parting a user from a channel we aren't in is a noop" do
    channels = Channels.init() |> Channels.user_part("#testchannel", "testnick")
    assert {:error, :no_such_channel} == Channels.channel_has_user?(channels, "#testchannel", "testnick")
  end

  test "Can quit a user from all channels" do
    channels =
      Channels.init()
      |> Channels.join("#testchannel")
      |> Channels.user_join("#testchannel", "testnick")
      |> Channels.join("#anotherchannel")
      |> Channels.user_join("#anotherchannel", "testnick")
      |> Channels.user_join("#anotherchannel", "secondnick")
    assert Channels.channel_has_user?(channels, "#testchannel", "testnick")
    channels = channels |> Channels.user_quit("testnick")
    refute Channels.channel_has_user?(channels, "#testchannel", "testnick")
    refute Channels.channel_has_user?(channels, "#anotherchannel", "testnick")
    assert Channels.channel_has_user?(channels, "#anotherchannel", "secondnick")
  end

  test "Can rename a user" do
    channels = Channels.init() 
                |> Channels.join("#testchannel") 
                |> Channels.join("#anotherchan") 
                |> Channels.user_join("#testchannel", "testnick")
                |> Channels.user_join("#anotherchan", "testnick")
    assert Channels.channel_has_user?(channels, "#testchannel", "testnick")
    assert Channels.channel_has_user?(channels, "#anotherchan", "testnick")
    channels = Channels.user_rename(channels, "testnick", "newnick")
    refute Channels.channel_has_user?(channels, "#testchannel", "testnick")
    refute Channels.channel_has_user?(channels, "#anotherchan", "testnick")
    assert Channels.channel_has_user?(channels, "#testchannel", "newnick")
    assert Channels.channel_has_user?(channels, "#anotherchan", "newnick")
  end

  test "Renaming a user that doesn't exist is a noop" do
    channels = Channels.init() |> Channels.join("#testchannel") |> Channels.user_rename("testnick", "newnick")
    refute Channels.channel_has_user?(channels, "#testchannel", "testnick")
    refute Channels.channel_has_user?(channels, "#testchannel", "newnick")
  end

  test "Can get the current set of channel data as a tuple of the channel name and it's data as a proplist" do
    channels = Channels.init() 
            |> Channels.join("#testchannel") 
            |> Channels.set_type("#testchannel", "@")
            |> Channels.set_topic("#testchannel", "Welcome to Test!")
            |> Channels.join("#anotherchan") 
            |> Channels.set_type("#anotherchan", "=")
            |> Channels.set_topic("#anotherchan", "Welcome to Another Channel!")
            |> Channels.user_join("#testchannel", "testnick")
            |> Channels.user_join("#anotherchan", "testnick")
            |> Channels.to_proplist
    testchannel = {"#testchannel", [users: ["testnick"], topic: "Welcome to Test!", type: :secret]}
    anotherchan = {"#anotherchan", [users: ["testnick"], topic: "Welcome to Another Channel!", type: :public]}
    assert [testchannel, anotherchan] == channels
  end
end
