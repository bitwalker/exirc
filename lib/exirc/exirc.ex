defmodule ExIrc do
  @moduledoc """
  Supervises IRC client processes

  Usage:

      # Start the supervisor (started automatically when ExIrc is run as an application)
      ExIrc.start_link

      # Start a new IRC client
      {:ok, client} = ExIrc.start_client!

      # Connect to an IRC server
      ExIrc.Client.connect! client, "localhost", 6667

      # Logon
      ExIrc.Client.logon client, "password", "nick", "user", "name"

      # Join a channel (password is optional)
      ExIrc.Client.join client, "#channel", "password"

      # Send a message
      ExIrc.Client.msg client, :privmsg, "#channel", "Hello world!"

      # Quit (message is optional)
      ExIrc.Client.quit client, "message"

      # Stop and close the client connection
      ExIrc.Client.stop! client

  """
  use Supervisor
  import Supervisor.Spec

  ##############
  # Public API
  ##############

  @doc """
  Start the ExIrc supervisor.
  """
  @spec start! :: {:ok, pid} | {:error, term}
  def start! do
    :supervisor.start_link({:local, :exirc}, __MODULE__, [])
  end

  @doc """
  Start a new ExIrc client
  """
  @spec start_client! :: {:ok, pid} | {:error, term}
  def start_client! do
    # Start the client worker
    :supervisor.start_child(:exirc, [])
  end

  ##############
  # Supervisor API
  ##############

  @spec init(any) :: {:ok, pid} | {:error, term}
  def init(_) do
    children = [
      worker(ExIrc.Client, [], restart: :transient)
    ]
    supervise children, strategy: :simple_one_for_one
  end

end
