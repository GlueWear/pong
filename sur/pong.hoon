::  sur/pong -- lobby and relay vocabulary for %pong.
::
::  The agent only seats players and carries messages between them.  Ball
::  physics, paddles and score live in the two browsers; to the agent a
::  game message is an opaque cord (body) addressed to the opponent.
::
|%
+$  gid  @t
::
::  status: where a game stands, from OUR side
::
+$  status
  $?  %open                                     ::  hosting, anyone may join
      %invited                                  ::  hosting, waiting on a guest
      %incoming                                 ::  challenged by someone else
      %joining                                  ::  asked a host for a seat
      %live                                     ::  both players seated
      %over                                     ::  ended, or a join failed
  ==
::
::  open: an open table returns to %open when its guest leaves;
::  a direct challenge ends instead.
::
+$  game
  $:  host=@p
      guest=(unit @p)
      =status
      open=?
      created=@da
  ==
::
::  action: from our own frontend
::
+$  action
  $%  [%host =gid]                              ::  open a table
      [%challenge =gid who=@p]                  ::  invite one ship
      [%join =gid host=@p]                      ::  take a seat
      [%leave =gid]                             ::  decline/cancel/quit/dismiss
      [%relay =gid body=@t]                     ::  game message to opponent
  ==
::
::  msg: ship to ship
::
+$  msg
  $%  [%invite =gid]                            ::  host -> guest
      [%join =gid]                              ::  guest -> host
      [%seat =gid]                              ::  host -> guest: you're in
      [%refuse =gid why=@t]                     ::  host -> guest: no seat
      [%leave =gid]                             ::  either way
      [%relay =gid body=@t]                     ::  either way
  ==
--
