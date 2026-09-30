::  mar/pong-action -- frontend pokes, parsed from JSON.
::
::    {"host":{"gid":"k3j2h1"}}
::    {"challenge":{"gid":"k3j2h1","who":"~sampel-palnet"}}
::    {"join":{"gid":"k3j2h1","host":"~sampel-palnet"}}
::    {"leave":{"gid":"k3j2h1"}}
::    {"relay":{"gid":"k3j2h1","body":"{\"t\":\"p\",\"y\":250}"}}
::
/-  pong
|_  act=action:pong
++  grab
  |%
  ++  noun  action:pong
  ++  json
    |=  jon=^json
    ^-  action:pong
    =,  dejs:format
    %.  jon
    %-  of
    :~  [%host (ot ~[gid+so])]
        [%challenge (ot ~[gid+so who+(se %p)])]
        [%join (ot ~[gid+so host+(se %p)])]
        [%leave (ot ~[gid+so])]
        [%relay (ot ~[gid+so body+so])]
    ==
  --
++  grow
  |%
  ++  noun  act
  --
++  grad  %noun
--
