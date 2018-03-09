defmodule ExIRC.Whois do

  defstruct [account_name: nil,
             channels: [],
             helpop?: false,
             hostname: nil,
             idling_time: 0,
             ircop?: false,
             nick: nil,
             name: nil,
             registered_nick?: false,
             server_address: nil,
             server_name: nil,
             signon_time: 0,
             ssl?: false,
             user: nil,
            ]
end

