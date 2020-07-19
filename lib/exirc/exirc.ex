defmodule ExIRC do
  @moduledoc """
  Supervises IRC client processes

  Usage:

      # Start the supervisor (started automatically when ExIRC is run as an application)
      ExIRC.start_link

      # Start a new IRC client
      {:ok, client} = ExIRC.start_client!

      # Connect to an IRC server
      ExIRC.Client.connect! client, "localhost", 6667

      # Logon
      ExIRC.Client.logon client, "password", "nick", "user", "name"

      # Join a channel (password is optional)
      ExIRC.Client.join client, "#channel", "password"

      # Send a message
      ExIRC.Client.msg client, :privmsg, "#channel", "Hello world!"

      # Quit (message is optional)
      ExIRC.Client.quit client, "message"

      # Stop and close the client connection
      ExIRC.Client.stop! client

  """
  use DynamicSupervisor

  defmodule TemporaryClient do
    @moduledoc """
    Temporary ExIRC.Client.
    """

    @doc """
    Defines how this module will run as a child process.
    """
    def child_spec(arg) do
      %{
        id: __MODULE__,
        start: {ExIRC.Client, :start_link, [arg]},
        restart: :temporary
      }
    end
  end

  ##############
  # Public API
  ##############

  @doc """
  Start the ExIRC supervisor.
  """
  @spec start!() :: Supervisor.on_start()
  def start! do
    DynamicSupervisor.start_link(__MODULE__, [], name: :exirc)
  end

  @doc """
  Start a new ExIRC client under the ExIRC supervisor
  """
  @spec start_client!() :: DynamicSupervisor.on_start_child()
  def start_client!() do
    DynamicSupervisor.start_child(:exirc, {TemporaryClient, owner: self()})
  end

  @doc """
  Start a new ExIRC client
  """
  @spec start_link!() :: GenServer.on_start()
  def start_link! do
    ExIRC.Client.start!(owner: self())
  end

  ##############
  # Supervisor API
  ##############

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
