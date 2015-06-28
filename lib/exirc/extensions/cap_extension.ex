defmodule ExIrc.Extensions.CapExtension do
  @moduledoc """
  Provides support for parsing CAP LS messages, and storing
  the metadata in the client state.
  """
  require Logger
  use ExIrc.Extensions.Extension
  alias ExIrc.Client.ClientState


  def handle(%IrcMessage{cmd: "CAP", args: args}, %ClientState{capabilities: capabilities} = state) do
    case args do
      [_nick, "LS" | caps] ->
        %{state | :capabilities => caps ++ capabilities}
      _ ->
        Logger.info "Unrecognized args for CAP LS message: #{Macro.to_string(args)}"
        state
    end
  end
  def handle(_, state), do: state
end
