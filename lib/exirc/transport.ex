defmodule ExIRC.Client.Transport do
  def connect(%{ssl?: false}, host, port, options) do
    :gen_tcp.connect(host, port, options)
  end
  def connect(%{ssl?: true}, host, port, options) do
    :ssl.connect(host, port, options)
  end

  def send(%{ssl?: false, socket: socket}, data) do
    :gen_tcp.send(socket, data)
  end
  def send(%{ssl?: true, socket: socket}, data) do
    :ssl.send(socket, data)
  end

  def close(%{ssl?: false, socket: socket}) do
    :gen_tcp.close(socket)
  end
  def close(%{ssl?: true, socket: socket}) do
    :ssl.close(socket)
  end
end
