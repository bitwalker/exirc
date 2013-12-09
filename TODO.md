# TODO

- Channels is returning empty lists for users, topic, and type when joined to a channel.
    - Probably not being set when joining for some reason
    - Why would topic and type be lists?
- Client.channels returns a list of channels, is that what we want, or do we want details?
- Need to test add/remove handlers
- Need to ensure PONGs are sent when PINGs are received
- Client.state was broken, fix implemented, test to make sure it works now
- Need to add type specs
- Test various outside changes such as channel topic changing, users leaving/entering, users changing their nicks
