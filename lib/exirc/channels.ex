defmodule ExIrc.Channels do
  @moduledoc """
  Responsible for managing channel state
  """
  use Irc.Commands

  import String, only: [downcase: 1]

  defrecord Channel,
    name:  '',
    topic: '',
    users: [],
    modes: '',
    type:  ''

  def init() do
    :gb_trees.empty()
  end

  ##################
  # Self JOIN/PART
  ##################
  def join(channel_tree, channel_name) do
    name = downcase(channel_name)
    case :gb_trees.lookup(name, channel_tree) do
      {:value, _} ->
        channel_tree
      :none ->
        :gb_trees.insert(name, Channel.new(name: name), channel_tree)
    end
  end

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
  def set_topic(channel_tree, channel_name, topic) do
    name = downcase(channel_name)
    case :gb_trees.lookup(name, channel_tree) do
      {:value, channel} ->
        :gb_trees.enter(name, channel.topic(topic), channel_tree)
      :none ->
        channel_tree
    end
  end

  def set_type(channel_tree, channel_name, channel_type) when is_binary(channel_type) do
    set_type(channel_tree, channel_name, String.to_char_list!(channel_type))
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
        :gb_trees.enter(name, channel.type(type), channel_tree)
      :none ->
        channel_tree
    end
  end

  ####################################
  # Users JOIN/PART/AKAs(namechange)
  ####################################
  def user_join(channel_tree, channel_name, nick) when not is_list(nick) do
    users_join(channel_tree, channel_name, [nick])
  end

  def users_join(channel_tree, channel_name, nicks) do
    pnicks = strip_rank(nicks)
    manipfn = fn(channel_nicks) -> :lists.usort(channel_nicks ++ pnicks) end
    users_manip(channel_tree, channel_name, manipfn)
  end

  def user_part(channel_tree, channel_name, nick) do
    pnick = strip_rank([nick])
    manipfn = fn(channel_nicks) -> :lists.usort(channel_nicks -- pnick) end
    users_manip(channel_tree, channel_name, manipfn)
  end

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
  def channels(channel_tree) do
    (lc {channel_name, _chan} inlist :gb_trees.to_list(channel_tree), do: channel_name) |> Enum.reverse
  end

  def channel_users(channel_tree, channel_name) do
    get_attr(channel_tree, channel_name, fn(Channel[users: users]) -> users end) |> Enum.reverse
  end

  def channel_topic(channel_tree, channel_name) do
    case get_attr(channel_tree, channel_name, fn(Channel[topic: topic]) -> topic end) do
      []    -> "No topic"
      topic -> topic
    end
  end

  def channel_type(channel_tree, channel_name) do
    case get_attr(channel_tree, channel_name, fn(Channel[type: type]) -> type end) do
      []   -> :unknown
      type -> type
    end
  end

  def channel_has_user?(channel_tree, channel_name, nick) do
    get_attr(channel_tree, channel_name, fn(Channel[users: users]) -> :lists.member(nick, users) end)
  end

  def to_proplist(channel_tree) do
    (lc {channel_name, chan} inlist :gb_trees.to_list(channel_tree), do: {
      channel_name, [users: chan.users, topic: chan.topic, type: chan.type]
    }) |> Enum.reverse
  end

  ####################
  # Internal API
  ####################
  defp users_manip(channel_tree, channel_name, manipfn) do
    name = downcase(channel_name)
    case :gb_trees.lookup(name, channel_tree) do
      {:value, channel} ->
        channel_list = manipfn.(channel.users)
        :gb_trees.enter(channel_name, channel.users(channel_list), channel_tree)
      :none ->
        channel_tree
    end
  end

  defp strip_rank(nicks) do
    nicks |> Enum.map(fn(n) -> case n do
        [?@ | nick] -> nick
        [?+ | nick] -> nick
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