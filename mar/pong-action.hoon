::  mar/pong-action -- frontend pokes, parsed from JSON.
::
::    {"host":{"gid":"k3j2h1"}}
::    {"challenge":{"gid":"k3j2h1","who":"~sampel-palnet"}}
::    {"follow":{"gid":"k3j2h1","host":"~sampel-palnet"}}
::    {"sit":{"gid":"k3j2h1","host":"~sampel-palnet","side":"l"}}
::    {"stand":{"gid":"k3j2h1","host":"~sampel-palnet"}}
::    {"score":{"gid":"k3j2h1","host":"~sampel-palnet","l":3,"r":5}}
::    {"here":{"gid":"k3j2h1","host":"~sampel-palnet"}}
::    {"close":{"gid":"k3j2h1"}}
::    {"dismiss":{"gid":"k3j2h1"}}
::    {"relay":{"gid":"k3j2h1","to":"~sampel-palnet","body":"{\"t\":\"p\",\"y\":250}"}}
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
        [%follow (ot ~[gid+so host+(se %p)])]
        [%sit (ot ~[gid+so host+(se %p) side+(su (perk %l %r ~))])]
        [%stand (ot ~[gid+so host+(se %p)])]
        [%score (ot ~[gid+so host+(se %p) l+ni r+ni])]
        [%here (ot ~[gid+so host+(se %p)])]
        [%close (ot ~[gid+so])]
        [%dismiss (ot ~[gid+so])]
        [%relay (ot ~[gid+so to+(se %p) body+so])]
    ==
  --
++  grow
  |%
  ++  noun  act
  --
++  grad  %noun
--
