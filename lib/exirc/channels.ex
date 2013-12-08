defmodule ExIrc.Channels do
  @moduledoc """
  Responsible for managing channel interaction
  """
  use Irc.Commands

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
  def join(struct, channel_name) do
    name = chan2lower(channel_name)
    case :gb_trees.lookup(name, struct) do
      {:value, _} ->
        struct
      :none ->
        :gb_trees.insert(name, Channel.new(name: name), struct)
    end
  end

  def part(struct, channel_name) do
    name = chan2lower(channel_name)
    :gb_trees.delete(name, struct)
  end

  ###########################
  # Channel Modes/Attributes
  ###########################
  def set_topic(struct, channel_name, topic) do
    name = chan2lower(channel_name)
    channel = :gb_trees.get(name, struct)
    :gb_trees.enter(name, channel.topic(topic), struct)
  end

  def set_type(struct, channel_name, channel_type) do
    name = chan2lower(channel_name)
    channel = :gb_trees.get(name, struct)
    type = case channel_type do
         '@' -> :secret
         '*' -> :private
         '=' -> :public
    end
    :gb_trees.enter(name, channel.type(type), struct)
  end

  ####################################
  # Users JOIN/PART/AKAs(namechange)
  ####################################
  def user_join(struct, channel_name, nick) do
    users_join(struct, channel_name, [nick])
  end

  def users_join(struct, channel_name, nicks) do
    pnicks = strip_rank(nicks)
    manipfn = fn(channel_nicks) -> :lists.usort(channel_nicks ++ pnicks) end
    users_manip(struct, channel_name, manipfn)
  end

  def user_part(struct, channel_name, nick) do
    pnick = strip_rank([nick])
    manipfn = fn(channel_nicks) -> :lists.usort(channel_nicks -- pnick) end
    users_manip(struct, channel_name, manipfn)
  end

  def user_rename(struct, nick, new_nick) do
    manipfn = fn(channel_nicks) ->
      case :lists.member(nick, channel_nicks) do
        true  -> :lists.usort([new_nick | channel_nicks -- [nick]])
        false -> channel_nicks
       end
    end
    foldl = fn(channel_name, new_struct) ->
      name = chan2lower(channel_name)
      users_manip(new_struct, name, manipfn)
    end
    :lists.foldl(foldl, struct, channels(struct))
  end

  def users_manip(struct, channel_name, manipfn) do
    name = chan2lower(channel_name)
    channel = :gb_trees.get(name, struct)
    channel_list = manipfn.(channel.users)
    :gb_trees.enter(channel_name, channel.users(channel_list), struct)
  end

  ################
  # Introspection
  ################
  def channels(struct) do
    lc {channel_name, _chan} inlist :gb_trees.to_list(struct), do: channel_name
  end

  def chan_users(struct, channel_name) do
    get_attr(struct, channel_name, fn(Channel[users: users]) -> users end)
  end

  def chan_topic(struct, channel_name) do
    get_attr(struct, channel_name, fn(Channel[topic: topic]) -> topic end)
  end

  def chan_type(struct, channel_name) do
    get_attr(struct, channel_name, fn(Channel[type: type]) -> type end)
  end

  def chan_has_user(struct, channel_name, nick) do
    get_attr(struct, channel_name, fn(Channel[users: users]) -> :lists.member(nick, users) end)
  end

  def to_proplist(struct) do
    lc {channel_name, chan} inlist :gb_trees.to_list(struct), do: {
      channel_name, [users: chan.users, topic: chan.topic, type: chan.type]
    }
  end

  ####################
  # Internal API
  ####################
  defp chan2lower(channel_name), do: String.downcase(channel_name)

  defp strip_rank(nicks) do
    nicks |> Enum.map(fn(n) -> case n do
        [?@ | nick] -> nick
        [?+ | nick] -> nick
        nick -> nick
      end
    end)
  end

  defp get_attr(struct, channel_name, getfn) do
    name = chan2lower(channel_name)
    case :gb_trees.lookup(name, struct) do
      {:value, channel} -> getfn.(channel)
      :none -> {:error, :no_such_channel}
    end
  end

end