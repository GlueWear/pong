::  sur/pong -- tables, seats and the ship-to-ship vocabulary for %pong.
::
::  A table lives on the ship that opened it (its host).  The host's agent
::  decides who holds which paddle: first come, first served.  Other ships
::  follow a table to see its seats and score.  The game itself runs in the
::  players' browsers, which talk to each other directly over WebRTC and
::  fall back to %relay through their ships when they can't.
::
|%
+$  gid  @t
+$  side  ?(%l %r)
::
+$  table
  $:  host=@p
      left=(unit @p)                            ::  left paddle
      right=(unit @p)                           ::  right paddle
      invite=(unit @p)                          ::  right paddle held for
      score=[l=@ud r=@ud]                       ::  as the players report it
      created=@da
  ==
::
::  action: from our own frontend
::
+$  action
  $%  [%host =gid]                              ::  open a table
      [%challenge =gid who=@p]                  ::  open, sit left, invite
      [%follow =gid host=@p]                    ::  see seats and score
      [%sit =gid host=@p =side]
      [%stand =gid host=@p]
      [%score =gid host=@p l=@ud r=@ud]
      [%here =gid host=@p]                      ::  still at the table
      [%close =gid]                             ::  shut a table we host
      [%dismiss =gid]                           ::  forget a table or invite
      [%relay =gid to=@p body=@t]               ::  to a page on another ship
  ==
::
::  msg: ship to ship
::
+$  msg
  $%  [%invite =gid]                            ::  host -> invitee
      [%decline =gid]                           ::  invitee -> host
      [%sit =gid =side]                         ::  -> host
      [%stand =gid]                             ::  -> host
      [%score =gid l=@ud r=@ud]                 ::  player -> host
      [%here =gid]                              ::  player -> host, heartbeat
      [%refuse =gid why=@t]                     ::  host -> asker
      [%relay =gid body=@t]                     ::  page to page
  ==
::
::  update: host -> followers, on /table/<gid>.  A closed table keeps its
::  followers, so reopening it reaches them.
::
+$  update
  $%  [%table =gid =table]
      [%closed =gid]
  ==
--
