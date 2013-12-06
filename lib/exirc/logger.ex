defmodule Logger do
    def warning(msg) do
        IO.puts(IO.ANSI.magenta() <> msg <> IO.ANSI.reset())
    end

    def error(msg) do
        IO.puts(IO.ANSI.red() <> msg <> IO.ANSI.reset())
    end
end