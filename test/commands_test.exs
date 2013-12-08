defmodule ExIrc.CommandsTest do
  use ExUnit.Case

  use Irc.Commands

  test "Commands are formatted properly" do
  	assert [1, 'TESTCMD', 1] == ctcp! 'TESTCMD'
  	assert [1, 'TESTCMD', 1] == ctcp! "TESTCMD"
  	assert [['PASS ', 'testpass'], '\r\n'] == pass! 'testpass'
  	assert [['PASS ', 'testpass'], '\r\n'] == pass! "testpass"
  	assert [['NICK ', 'testnick'], '\r\n'] == nick! 'testnick'
  	assert [['NICK ', 'testnick'], '\r\n'] == nick! "testnick"
  	assert [['USER ', 'testuser', ' 0 * :', 'Test User'], '\r\n'] == user! 'testuser', 'Test User'
  	assert [['USER ', 'testuser', ' 0 * :', 'Test User'], '\r\n'] == user! "testuser", 'Test User'
  	assert [['USER ', 'testuser', ' 0 * :', 'Test User'], '\r\n'] == user! 'testuser', "Test User"
  	assert [['USER ', 'testuser', ' 0 * :', 'Test User'], '\r\n'] == user! "testuser", "Test User"
  	assert [['PONG ', 'testnick'], '\r\n'] == pong1! 'testnick' 
  	assert [['PONG ', 'testnick'], '\r\n'] == pong1! "testnick"
  	assert [['PONG ', 'testnick', ' ', 'othernick'], '\r\n'] == pong2! 'testnick', 'othernick'
  	assert [['PONG ', 'testnick', ' ', 'othernick'], '\r\n'] == pong2! "testnick", 'othernick'
  	assert [['PONG ', 'testnick', ' ', 'othernick'], '\r\n'] == pong2! 'testnick', "othernick"
  	assert [['PONG ', 'testnick', ' ', 'othernick'], '\r\n'] == pong2! "testnick", "othernick"
  	assert [['PRIVMSG ', 'testnick', ' :', 'Test message!'], '\r\n'] == privmsg! 'testnick', 'Test message!'
  	assert [['PRIVMSG ', 'testnick', ' :', 'Test message!'], '\r\n'] == privmsg! "testnick", 'Test message!'
  	assert [['PRIVMSG ', 'testnick', ' :', 'Test message!'], '\r\n'] == privmsg! 'testnick', "Test message!"
  	assert [['PRIVMSG ', 'testnick', ' :', 'Test message!'], '\r\n'] == privmsg! "testnick", "Test message!"
  	assert [['NOTICE ', 'testnick', ' :', 'Test notice!'], '\r\n'] == notice! 'testnick', 'Test notice!'
  	assert [['NOTICE ', 'testnick', ' :', 'Test notice!'], '\r\n'] == notice! "testnick", 'Test notice!'
  	assert [['NOTICE ', 'testnick', ' :', 'Test notice!'], '\r\n'] == notice! 'testnick', "Test notice!"
  	assert [['NOTICE ', 'testnick', ' :', 'Test notice!'], '\r\n'] == notice! "testnick", "Test notice!"
  	assert [['JOIN ', 'testchan', ' ', ''], '\r\n'] == join! 'testchan'
  	assert [['JOIN ', 'testchan', ' ', ''], '\r\n'] == join! "testchan"
  	assert [['JOIN ', 'testchan', ' ', 'chanpass'], '\r\n'] == join! 'testchan', 'chanpass'
  	assert [['JOIN ', 'testchan', ' ', 'chanpass'], '\r\n'] == join! "testchan", 'chanpass'
  	assert [['JOIN ', 'testchan', ' ', 'chanpass'], '\r\n'] == join! 'testchan', "chanpass"
  	assert [['JOIN ', 'testchan', ' ', 'chanpass'], '\r\n'] == join! "testchan", "chanpass"
  	assert [['PART ', 'testchan'], '\r\n'] == part! 'testchan'
  	assert [['PART ', 'testchan'], '\r\n'] == part! "testchan"
  	assert [['QUIT :', 'Leaving'], '\r\n'] == quit!
  	assert [['QUIT :', 'Goodbye, cruel world.'], '\r\n'] == quit! 'Goodbye, cruel world.'
  	assert [['QUIT :', 'Goodbye, cruel world.'], '\r\n'] == quit! "Goodbye, cruel world."
  end
end