defmodule ExIrc.ExampleHandler do
  use GenEvent.Behaviour

  ################
  # GenEvent API
  ################

  def init(args) do
    {:ok, args}
  end

  def handle_event(:connected, state) do
    IO.puts "Received event :connected"
    {:ok, state}
  end
  def handle_event(:login, state) do
    IO.puts "Received event :login"
    {:ok, state}
  end

end
