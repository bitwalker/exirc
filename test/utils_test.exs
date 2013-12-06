defmodule ExIrc.UtilsTest do
  use ExUnit.Case
  alias ExIrc.Utils, as: Utils
  alias ExIrc.Client.IrcMessage, as: IrcMessage
  alias ExIrc.Client.ClientState, as: ClientState

  test "Given a local date/time as a tuple, can retrieve get the CTCP formatted time" do
  	local_time = {{2013,12,6},{14,5,00}}
  	assert Utils.ctcp_time(local_time) == 'Fri Dec 06 14:05:00 2013'
  end

  test "Can parse an IRC message" do
  	message = ':irc.example.org 005 nick PREFIX=(ov)@+ CHANTYPES=#&'
  	assert IrcMessage[server: 'irc.example.org', cmd: '005', args: ['nick', 'PREFIX=(ov)@+', 'CHANTYPES=#&']] = Utils.parse(message)
  end

end
