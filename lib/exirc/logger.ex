defmodule ExIrc.Logger do
  def notice(msg) do
    IO.puts(IO.ANSI.cyan() <> msg <> IO.ANSI.reset())
  end

  def warning(msg) do
    IO.puts(IO.ANSI.magenta() <> msg <> IO.ANSI.reset())
  end

  def error(msg) do
    IO.puts(IO.ANSI.red() <> msg <> IO.ANSI.reset())
  end
end