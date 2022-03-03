defmodule ExIRC.Channels do
  @moduledoc """
  Responsible for managing channel state
  """
  use ExIRC.Commands

  import String, only: [downcase: 1]

  defmodule Channel do
    defstruct name:  '',
              topic: '',
              users: [],
              modes: '',
              type:  ''
  end

  @doc """
  Initialize a new Channels data store
  """
  def init() do
    :gb_trees.empty()
  end

  ##################
  # Self JOIN/PART
  ##################

  @doc """
  Add a channel to the data store when joining a channel
  """
  def join(channel_tree, channel_name) do
    name = downcase(channel_name)
    case :gb_trees.lookup(name, channel_tree) do
      {:value, _} ->
        channel_tree
      :none ->
        :gb_trees.insert(name, %Channel{name: name}, channel_tree)
    end
  end

  @doc """
  Remove a channel from the data store when leaving a channel
  """
  def part(channel_tree, channel_name) do
    name = downcase(channel_name)
    case :gb_trees.lookup(name, channel_tree) do
      {:value, _} ->
        :gb_trees.delete(name, channel_tree)
      :none ->
        channel_tree
    end
  end

  ###########################
  # Channel Modes/Attributes
  ###########################

  @doc """
  Update the topic for a tracked channel when it changes
  """
  def set_topic(channel_tree, channel_name, topic) do
    name = downcase(channel_name)
    case :gb_trees.lookup(name, channel_tree) do
      {:value, channel} ->
        :gb_trees.enter(name, %{channel | topic: topic}, channel_tree)
      :none ->
        channel_tree
    end
  end

  @doc """
  Update the type of a tracked channel when it changes
  """
  def set_type(channel_tree, channel_name, channel_type) when is_binary(channel_type) do
    set_type(channel_tree, channel_name, String.to_charlist(channel_type))
  end
  def set_type(channel_tree, channel_name, channel_type) do
    name = downcase(channel_name)
    case :gb_trees.lookup(name, channel_tree) do
      {:value, channel} ->
        type = case channel_type do
             '@' -> :secret
             '*' -> :private
             '=' -> :public
        end
        :gb_trees.enter(name, %{channel | type: type}, channel_tree)
      :none ->
        channel_tree
    end
  end

  ####################################
  # Users JOIN/PART/AKAs(namechange)
  ####################################

  @doc """
  Add a user to a tracked channel when they join
  """
  def user_join(channel_tree, channel_name, nick) when not is_list(nick) do
    users_join(channel_tree, channel_name, [nick])
  end

  @doc """
  Add multiple users to a tracked channel (used primarily in conjunction with the NAMES command)
  """
  def users_join(channel_tree, channel_name, nicks) do
    pnicks = trim_rank(nicks)
    manipfn = fn(channel_nicks) -> :lists.usort(channel_nicks ++ pnicks) end
    users_manip(channel_tree, channel_name, manipfn)
  end

  @doc """
  Remove a user from a tracked channel when they leave
  """
  def user_part(channel_tree, channel_name, nick) do
    pnick = trim_rank([nick])
    manipfn = fn(channel_nicks) -> :lists.usort(channel_nicks -- pnick) end
    users_manip(channel_tree, channel_name, manipfn)
  end

  def user_quit(channel_tree, nick) do
    pnick = trim_rank([nick])
    manipfn = fn(channel_nicks) -> :lists.usort(channel_nicks -- pnick) end
    foldl = fn(channel_name, new_channel_tree) ->
      name = downcase(channel_name)
      users_manip(new_channel_tree, name, manipfn)
    end
    :lists.foldl(foldl, channel_tree, channels(channel_tree))
  end

  @doc """
  Update the nick of a user in a tracked channel when they change their nick
  """
  def user_rename(channel_tree, nick, new_nick) do
    manipfn = fn(channel_nicks) ->
      case Enum.member?(channel_nicks, nick) do
        true  -> [new_nick | channel_nicks -- [nick]] |> Enum.uniq |> Enum.sort
        false -> channel_nicks
       end
    end
    foldl = fn(channel_name, new_channel_tree) ->
      name = downcase(channel_name)
      users_manip(new_channel_tree, name, manipfn)
    end
    :lists.foldl(foldl, channel_tree, channels(channel_tree))
  end

  ################
  # Introspection
  ################

  @doc """
  Get a list of all currently tracked channels
  """
  def channels(channel_tree) do
    (for {channel_name, _chan} <- :gb_trees.to_list(channel_tree), do: channel_name) |> Enum.reverse
  end

  @doc """
  Get a list of all users in a tracked channel
  """
  def channel_users(channel_tree, channel_name) do
    case get_attr(channel_tree, channel_name, fn(%Channel{users: users}) -> users end) do
      {:error, _} = error -> error
      users -> Enum.reverse(users)
    end
  end

  @doc """
  Get the current topic for a tracked channel
  """
  def channel_topic(channel_tree, channel_name) do
    case get_attr(channel_tree, channel_name, fn(%Channel{topic: topic}) -> topic end) do
      []    -> "No topic"
      topic -> topic
    end
  end

  @doc """
  Get the type of a tracked channel
  """
  def channel_type(channel_tree, channel_name) do
    case get_attr(channel_tree, channel_name, fn(%Channel{type: type}) -> type end) do
      []   -> :unknown
      type -> type
    end
  end

  @doc """
  Determine if a user is present in a tracked channel
  """
  def channel_has_user?(channel_tree, channel_name, nick) do
    get_attr(channel_tree, channel_name, fn(%Channel{users: users}) -> :lists.member(nick, users) end)
  end

  @doc """
  Get all channel data as a tuple of the channel name and a proplist of metadata.

  Example Result:

      [{"#testchannel", [users: ["userA", "userB"], topic: "Just a test channel.", type: :public] }]
  """
  def to_proplist(channel_tree) do
    for {channel_name, chan} <- :gb_trees.to_list(channel_tree) do
      {channel_name, [users: chan.users, topic: chan.topic, type: chan.type]}
    end |> Enum.reverse
  end

  ####################
  # Internal API
  ####################
  defp users_manip(channel_tree, channel_name, manipfn) do
    name = downcase(channel_name)
    case :gb_trees.lookup(name, channel_tree) do
      {:value, channel} ->
        channel_list = manipfn.(channel.users)
        :gb_trees.enter(channel_name, %{channel | users: channel_list}, channel_tree)
      :none ->
        channel_tree
    end
  end

  defp trim_rank(nicks) do
    nicks |> Enum.map(fn(n) -> case n do
        << "@", nick :: binary >> -> nick
        << "+", nick :: binary >> -> nick
        << "%", nick :: binary >> -> nick
        << "&", nick :: binary >> -> nick
        << "~", nick :: binary >> -> nick
        nick -> nick
      end
    end)
  end

  defp get_attr(channel_tree, channel_name, getfn) do
    name = downcase(channel_name)
    case :gb_trees.lookup(name, channel_tree) do
      {:value, channel} -> getfn.(channel)
      :none -> {:error, :no_such_channel}
    end
  end

end
