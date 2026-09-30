::  pong -- ship-vs-ship Pong.
::
::  Seats two players and relays their game messages over Ames.  The
::  browsers run the game: each side is authoritative for hits and misses
::  on its own paddle, so the agent never sees the ball.  Relays are not
::  stored; only the lobby (who is seated where) is state.
::
/-  pong
/+  default-agent, dbug, server
|%
+$  versioned-state
  $%  state-0
  ==
+$  state-0  [%0 games=(map gid:pong game:pong)]
+$  card  card:agent:gall
::
++  max-body  4.096                             ::  relay body, bytes
++  max-incoming  16                            ::  unanswered challenges
::
::  Noltbook plugin manifest.  "media" is required, not decorative:
::  Noltbook only grants allow-same-origin to media frames, and without
::  it the iframe cannot reach this agent through the Eyre channel.
::
++  manifest
  ^-  @t
  '{"noltbookVersion":"365K","version":"0.1.0","title":"Pong","summary":"Ship-vs-ship Pong. First to 11.","permissions":["media"],"launch":{"href":"/apps/pong","target":"embedded","width":900,"height":640,"media":true},"artifact":{"label":"Pong","href":"/apps/pong","width":660,"height":500,"media":true},"actions":[{"id":"open","kind":"open","label":"Play Pong","description":"Challenge a ship or practice against the CPU.","href":"/apps/pong","target":"embedded","width":900,"height":640,"media":true}]}'
::
++  gid-ok
  |=  =gid:pong
  ^-  ?
  ?&  (gth (met 3 gid) 0)
      (lte (met 3 gid) 32)
      ((sane %ta) gid)
  ==
::
++  opponent
  |=  [our=@p g=game:pong]
  ^-  (unit @p)
  ?:  =(our host.g)  guest.g
  `host.g
::
++  game-json
  |=  [=gid:pong g=game:pong]
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  ['gid' s+gid]
      ['host' s+(scot %p host.g)]
      ['guest' ?~(guest.g ~ s+(scot %p u.guest.g))]
      ['status' s+status.g]
      ['open' b+open.g]
      ['created' (time created.g)]
  ==
::
++  fact
  |=  jon=json
  ^-  card
  [%give %fact ~[/updates] %json !>(jon)]
::
++  give-game
  |=  [=gid:pong g=game:pong]
  ^-  card
  (fact (frond:enjs:format 'game' (game-json gid g)))
::
++  give-gone
  |=  =gid:pong
  ^-  card
  (fact (frond:enjs:format 'gone' s+gid))
::
++  give-note
  |=  [=gid:pong text=@t]
  ^-  card
  %-  fact
  %+  frond:enjs:format  'note'
  (pairs:enjs:format ~[['gid' s+gid] ['text' s+text]])
::
++  give-relay
  |=  [=gid:pong body=@t]
  ^-  card
  %-  fact
  %+  frond:enjs:format  'relay'
  (pairs:enjs:format ~[['gid' s+gid] ['body' s+body]])
::
::  wire /msg/<gid>/<tag>: on-agent reads the tag to tell a failed
::  invite or join (worth reporting) from a dropped relay (not).
::
++  msg-gid
  |=  =msg:pong
  ^-  gid:pong
  ?-  -.msg
    %invite  gid.msg
    %join    gid.msg
    %seat    gid.msg
    %refuse  gid.msg
    %leave   gid.msg
    %relay   gid.msg
  ==
::
++  send
  |=  [who=@p =msg:pong]
  ^-  card
  :*  %pass  [%msg (msg-gid msg) -.msg ~]
      %agent  [who %pong]
      %poke  %pong-msg  !>(msg)
  ==
--
::
%-  agent:dbug
=|  state-0
=*  state  -
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
::
++  on-init
  ^-  (quip card _this)
  :_  this
  ~[[%pass /eyre-bind %arvo %e %connect [~ /apps/pong] %pong]]
::
++  on-save  !>(state)
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  prev  !<(versioned-state old)
  ?-  -.prev
    %0  `this(state prev)
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+    mark  (on-poke:def mark vase)
      %pong-action
    ?>  =(src.bowl our.bowl)
    =/  act  !<(action:pong vase)
    ?-    -.act
        %host
      ?>  (gid-ok gid.act)
      ?<  (~(has by games) gid.act)
      =/  g=game:pong  [our.bowl ~ %open %.y now.bowl]
      :_  this(games (~(put by games) gid.act g))
      ~[(give-game gid.act g)]
    ::
        %challenge
      ?>  (gid-ok gid.act)
      ?<  (~(has by games) gid.act)
      ?<  =(who.act our.bowl)
      =/  g=game:pong  [our.bowl `who.act %invited %.n now.bowl]
      :_  this(games (~(put by games) gid.act g))
      :~  (give-game gid.act g)
          (send who.act [%invite gid.act])
      ==
    ::
        %join
      ?>  (gid-ok gid.act)
      ?<  =(host.act our.bowl)
      =/  old  (~(get by games) gid.act)
      ?<  ?&(?=(^ old) =(host.u.old our.bowl))
      ?:  ?&  ?=(^ old)
              =(host.u.old host.act)
              ?=(%live status.u.old)
          ==
        ::  already seated: re-announce so a reloaded page can attach
        [~[(give-game gid.act u.old)] this]
      =/  g=game:pong  [host.act `our.bowl %joining %.n now.bowl]
      :_  this(games (~(put by games) gid.act g))
      :~  (give-game gid.act g)
          (send host.act [%join gid.act])
      ==
    ::
        %leave
      =/  old  (~(get by games) gid.act)
      ?~  old  `this
      =/  them  (opponent our.bowl u.old)
      =/  gone=(list card)  ~[(give-gone gid.act)]
      =.  games  (~(del by games) gid.act)
      ?:  ?=(%over status.u.old)  [gone this]
      ?~  them  [gone this]
      [(snoc gone (send u.them [%leave gid.act])) this]
    ::
        %relay
      =/  old  (~(get by games) gid.act)
      ?~  old  `this
      ?.  ?=(%live status.u.old)  `this
      ?.  (lte (met 3 body.act) max-body)  `this
      =/  them  (opponent our.bowl u.old)
      ?~  them  `this
      :_  this
      ~[(send u.them [%relay gid.act body.act])]
    ==
  ::
      %pong-msg
    =/  =msg:pong  !<(msg:pong vase)
    =/  who=@p  src.bowl
    =/  =gid:pong  (msg-gid msg)
    =/  old  (~(get by games) gid)
    ?-    -.msg
        %invite
      ?.  (gid-ok gid)  `this
      ?^  old  `this
      ?:  =(who our.bowl)  `this
      =/  waiting
        (skim ~(val by games) |=(g=game:pong ?=(%incoming status.g)))
      ?:  (gte (lent waiting) max-incoming)  `this
      =/  g=game:pong  [who `our.bowl %incoming %.n now.bowl]
      :_  this(games (~(put by games) gid g))
      ~[(give-game gid g)]
    ::
        %join
      ?~  old
        :_(this ~[(send who [%refuse gid 'no such table'])])
      ?.  =(host.u.old our.bowl)
        :_(this ~[(send who [%refuse gid 'not the host'])])
      ?:  ?&(?=(%live status.u.old) =(guest.u.old `who))
        ::  our guest again (reloaded, or a second tab): same seat
        :_(this ~[(send who [%seat gid])])
      ?.  ?|  ?=(%open status.u.old)
              ?&(?=(%invited status.u.old) =(guest.u.old `who))
          ==
        =/  why=@t
          ?:(?=(%live status.u.old) 'table is full' 'table is closed')
        :_(this ~[(send who [%refuse gid why])])
      =/  g=game:pong  u.old(guest `who, status %live)
      :_  this(games (~(put by games) gid g))
      :~  (give-game gid g)
          (send who [%seat gid])
      ==
    ::
        %seat
      ?~  old  `this
      ?.  =(host.u.old who)  `this
      ?.  ?=(?(%joining %live) status.u.old)  `this
      =/  g=game:pong  u.old(status %live)
      :_  this(games (~(put by games) gid g))
      ~[(give-game gid g)]
    ::
        %refuse
      ?~  old  `this
      ?.  =(host.u.old who)  `this
      ?.  ?=(%joining status.u.old)  `this
      =/  g=game:pong  u.old(status %over)
      :_  this(games (~(put by games) gid g))
      :~  (give-game gid g)
          (give-note gid why.msg)
      ==
    ::
        %leave
      ?~  old  `this
      ?.  =((opponent our.bowl u.old) `who)  `this
      ?:  ?&(=(host.u.old our.bowl) open.u.old)
        ::  our open table: free the seat for the next player
        =/  g=game:pong  u.old(guest ~, status %open)
        :_  this(games (~(put by games) gid g))
        :~  (give-game gid g)
            (give-note gid (crip "{(scow %p who)} left the table"))
        ==
      =/  g=game:pong  u.old(status %over)
      :_  this(games (~(put by games) gid g))
      :~  (give-game gid g)
          (give-note gid (crip "{(scow %p who)} left"))
      ==
    ::
        %relay
      ?~  old  `this
      ?.  ?=(%live status.u.old)  `this
      ?.  =((opponent our.bowl u.old) `who)  `this
      ?.  (lte (met 3 body.msg) max-body)  `this
      :_  this
      ~[(give-relay gid body.msg)]
    ==
  ::
      %handle-http-request
    =+  !<([eyre-id=@ta =inbound-request:eyre] vase)
    ?.  authenticated.inbound-request
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      (login-redirect:gen:server request.inbound-request)
    =/  url=tape  (trip url.request.inbound-request)
    =/  pax=tape
      =/  q  (find "?" url)
      ?~(q url (scag u.q url))
    ?:  =(pax "/apps/pong/noltbook.json")
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      :-  [200 ~[['content-type' 'application/json'] ['cache-control' 'no-store']]]
      `(as-octs:mimes:html manifest)
    =/  html-path=path
      :*  (scot %p our.bowl)
          q.byk.bowl
          (scot %da now.bowl)
          /lib/pong/index/html
      ==
    =/  page=@  .^(@ %cx html-path)
    :_  this
    %+  give-simple-payload:app:server  eyre-id
    :-  [200 ~[['content-type' 'text/html; charset=utf-8'] ['cache-control' 'no-store']]]
    `(as-octs:mimes:html page)
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+    path  (on-watch:def path)
      [%http-response *]  `this
  ::
      [%updates ~]
    ?>  =(src.bowl our.bowl)
    :_  this
    :~  :*  %give  %fact  ~  %json
            !>  ^-  json
            %-  pairs:enjs:format
            :~  ['our' s+(scot %p our.bowl)]
                ['games' a+(turn ~(tap by games) game-json)]
            ==
        ==
    ==
  ==
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  (on-peek:def path)
    [%x %games ~]  ``json+!>(`json`a+(turn ~(tap by games) game-json))
  ==
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?.  ?=(%poke-ack -.sign)  (on-agent:def wire sign)
  ?~  p.sign  `this
  ?.  ?&(=(3 (lent wire)) =(%msg (snag 0 wire)))  `this
  ::  only a refused invite or join is worth surfacing
  =/  tag=@ta  (snag 2 wire)
  ?.  |(=(%invite tag) =(%join tag))  `this
  =/  =gid:pong  (snag 1 wire)
  =/  old  (~(get by games) gid)
  ?~  old  `this
  =/  g=game:pong  u.old(status %over)
  :_  this(games (~(put by games) gid g))
  :~  (give-game gid g)
      (give-note gid 'their ship refused -- is %pong installed there?')
  ==
::
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?+  wire  (on-arvo:def wire sign-arvo)
    [%eyre-bind ~]  `this
  ==
::
++  on-leave  on-leave:def
++  on-fail   on-fail:def
--
