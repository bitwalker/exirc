defmodule ExIrc.Extensions.Extension do
  @moduledoc """
  Defines a behaviour for extending ExIrc with custom IRC extensions,
  for example, those defined in [IRCv3](https://github.com/ircv3/ircv3-specifications/tree/master/extensions).
  """
  use Behaviour
  alias ExIrc.Client.ClientState

  defcallback handle(message::%IrcMessage{}, state::%ClientState{})::%ClientState{}

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour ExIrc.Extensions.Extension
      import ExIrc.Extensions.Extension
    end
  end
end
