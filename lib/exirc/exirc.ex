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
  use Supervisor
  import Supervisor.Spec

  ##############
  # Public API
  ##############

  @doc """
  Start the ExIRC supervisor.
  """
  @spec start! :: {:ok, pid} | {:error, term}
  def start! do
    Supervisor.start_link(__MODULE__, [], name: :exirc)
  end

  @doc """
  Start a new ExIRC client under the ExIRC supervisor
  """
  @spec start_client! :: {:ok, pid} | {:error, term}
  def start_client! do
    # Start the client worker
    Supervisor.start_child(:exirc, [[owner: self()]])
  end

  @doc """
  Start a new ExIRC client
  """
  def start_link! do
    ExIRC.Client.start!([owner: self()])
  end

  ##############
  # Supervisor API
  ##############

  @spec init(any) :: {:ok, pid} | {:error, term}
  def init(_) do
    children = [
      worker(ExIRC.Client, [], restart: :temporary)
    ]
    supervise children, strategy: :simple_one_for_one
  end

end
