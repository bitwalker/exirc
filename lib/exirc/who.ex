defmodule ExIRC.Who do

  defstruct [
             admin?: nil,
             away?: nil,
             founder?: nil,
             half_operator?: nil,
             hops: nil,
             name: nil,
             nickname: nil,
             operator?: nil,
             server: nil,
             server_operator?: nil,
             user: nil,
             voiced?: nil
            ]
end
