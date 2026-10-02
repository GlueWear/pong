::  pong -- ship-vs-ship Pong.
::
::  A table lives on the ship that opened it.  This agent keeps the tables
::  we host (who holds which paddle, the score), mirrors tables we follow
::  on other ships, and carries page-to-page messages between ships.  Game
::  traffic normally goes browser to browser over WebRTC; %relay is the
::  signalling path and the fallback, and nothing it carries is stored.
::
::  Seated pages send a %here every 30s.  A seat that goes quiet for
::  seat-timeout is freed by a sweep that only runs while someone is seated.
::
/-  pong
/+  default-agent, dbug, server
|%
+$  versioned-state
  $%  state-1
      state-2
  ==
+$  state-1
  $:  %1
      tables=(map gid:pong table:pong)
      mirror=(map gid:pong table:pong)
      invites=(map gid:pong @p)
  ==
+$  state-2
  $:  %2
      tables=(map gid:pong table:pong)          ::  hosted here
      closed=(set gid:pong)                     ::  hosted here, shut for now
      seen=(map [gid:pong @p] @da)              ::  last heartbeat per seat
      sweep=(unit @da)                          ::  idle sweep, when armed
      mirror=(map gid:pong table:pong)          ::  followed elsewhere
      shut=(map gid:pong @p)                    ::  followed, closed by host
      invites=(map gid:pong @p)                 ::  gid -> host
  ==
+$  card  card:agent:gall
::
++  max-body  16.384                            ::  a WebRTC offer is a few KB
++  max-invites  16
++  seat-timeout  ~s90                          ::  pages beat every ~s30
++  sweep-every  ~s30
::
::  Noltbook plugin manifest.  "media" is required, not decorative:
::  Noltbook only grants allow-same-origin to media frames, and without
::  it the iframe cannot reach this agent through the Eyre channel.
::
++  manifest
  ^-  @t
  '{"noltbookVersion":"365K","version":"0.2.5","title":"Pong","summary":"Ship-vs-ship Pong. First to 11.","permissions":["media"],"launch":{"href":"/apps/pong","target":"embedded","width":900,"height":640,"media":true},"artifact":{"label":"Pong","href":"/apps/pong","width":660,"height":520,"media":true},"actions":[{"id":"open","kind":"open","label":"Play Pong","description":"Challenge a ship or practice against the CPU.","href":"/apps/pong","target":"embedded","width":900,"height":640,"media":true}]}'
::
++  gid-ok
  |=  =gid:pong
  ^-  ?
  ?&  (gth (met 3 gid) 0)
      (lte (met 3 gid) 32)
      ((sane %ta) gid)
  ==
::
++  msg-gid
  |=  =msg:pong
  ^-  gid:pong
  ?-  -.msg
    %invite   gid.msg
    %decline  gid.msg
    %sit      gid.msg
    %stand    gid.msg
    %score    gid.msg
    %here     gid.msg
    %refuse   gid.msg
    %relay    gid.msg
  ==
::
::  seat rules, shared by our own pokes and other ships'
::
++  seated
  |=  [t=table:pong who=@p]
  ^-  (unit side:pong)
  ?:  =(left.t `who)  `%l
  ?:  =(right.t `who)  `%r
  ~
::
++  sit
  |=  [t=table:pong who=@p =side:pong]
  ^-  (each table:pong @t)
  =/  now  (seated t who)
  ?^  now
    ?:  =(u.now side)  [%& t]
    [%| 'you already hold the other paddle']
  =/  seat=(unit @p)  ?-(side %l left.t, %r right.t)
  ?^  seat  [%| 'that paddle is taken']
  ?:  ?&(=(%r side) ?=(^ invite.t) !=(u.invite.t who))
    [%| 'that paddle is saved for someone else']
  ?-  side
    %l  [%& t(left `who, score [0 0])]
    %r  [%& t(right `who, invite ~, score [0 0])]
  ==
::
++  stand
  |=  [t=table:pong who=@p]
  ^-  table:pong
  ?:  =(left.t `who)  t(left ~, score [0 0])
  ?:  =(right.t `who)  t(right ~, score [0 0])
  t
::
::  idle seats
::
++  any-seated
  |=  tables=(map gid:pong table:pong)
  ^-  ?
  %-  ~(any by tables)
  |=(t=table:pong |(?=(^ left.t) ?=(^ right.t)))
::
++  arm
  |=  now=@da
  ^-  [(list card) (unit @da)]
  =/  at  (add now sweep-every)
  [~[[%pass /sweep %arvo %b %wait at]] `at]
::
::  heartbeats for exactly the seated ships; a seat with none yet
::  starts its clock now, so nobody is evicted without a full timeout
::
++  prune
  |=  [now=@da tables=(map gid:pong table:pong) seen=(map [gid:pong @p] @da)]
  ^-  (map [gid:pong @p] @da)
  %-  ~(rep by tables)
  |=  [[g=gid:pong t=table:pong] acc=(map [gid:pong @p] @da)]
  =/  keep
    |=  [who=(unit @p) acc=(map [gid:pong @p] @da)]
    ^+  acc
    ?~  who  acc
    (~(put by acc) [g u.who] (fall (~(get by seen) [g u.who]) now))
  (keep right.t (keep left.t acc))
::
++  evict
  |=  [now=@da seen=(map [gid:pong @p] @da) =gid:pong t=table:pong]
  ^-  table:pong
  =/  quiet
    |=  who=(unit @p)
    ^-  ?
    ?~  who  |
    =/  last  (~(get by seen) [gid u.who])
    ?~  last  |
    (gth (sub now u.last) seat-timeout)
  =?  t  (quiet left.t)  t(left ~, score [0 0])
  =?  t  (quiet right.t)  t(right ~, score [0 0])
  t
::
::  json for our own frontend
::
++  table-json
  |=  [=gid:pong t=table:pong]
  ^-  json
  =/  who  |=(u=(unit @p) ^-(json ?~(u ~ s+(scot %p u.u))))
  %-  pairs:enjs:format
  :~  ['gid' s+gid]
      ['host' s+(scot %p host.t)]
      ['left' (who left.t)]
      ['right' (who right.t)]
      ['invite' (who invite.t)]
      ['score' a+~[(numb:enjs:format l.score.t) (numb:enjs:format r.score.t)]]
      ['created' (time:enjs:format created.t)]
  ==
::
++  fact
  |=  jon=json
  ^-  card
  [%give %fact ~[/updates] %json !>(jon)]
::
++  give-table
  |=  [=gid:pong t=table:pong]
  ^-  card
  (fact (frond:enjs:format 'table' (table-json gid t)))
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
++  give-invite
  |=  [=gid:pong host=@p]
  ^-  card
  %-  fact
  %+  frond:enjs:format  'invite'
  (pairs:enjs:format ~[['gid' s+gid] ['host' s+(scot %p host)]])
::
++  give-relay
  |=  [=gid:pong from=@p body=@t]
  ^-  card
  %-  fact
  %+  frond:enjs:format  'relay'
  %-  pairs:enjs:format
  ~[['gid' s+gid] ['from' s+(scot %p from)] ['body' s+body]]
::
::  a hosted table changed: tell followers and our own pages
::
++  publish
  |=  [=gid:pong t=table:pong]
  ^-  (list card)
  :~  [%give %fact ~[[%table gid ~]] %pong-update !>(`update:pong`[%table gid t])]
      (give-table gid t)
  ==
::
::  wire /msg/<gid>/<tag>: on-agent reads the tag to tell a failed sit or
::  invite (worth reporting) from a dropped relay (not).
::
++  send
  |=  [who=@p =msg:pong]
  ^-  card
  :*  %pass  [%msg (msg-gid msg) -.msg ~]
      %agent  [who %pong]
      %poke  %pong-msg  !>(msg)
  ==
::
++  follow-wire
  |=  [=gid:pong host=@p]
  ^-  wire
  [%table gid (scot %p host) ~]
::
::  watch a remote table unless we already do (a second watch on the
::  same wire would crash)
::
++  follow
  |=  [=bowl:gall mirror=(map gid:pong table:pong) =gid:pong host=@p]
  ^-  (list card)
  ?:  (~(has by mirror) gid)  ~
  ?:  (~(has by wex.bowl) [(follow-wire gid host) host %pong])  ~
  ~[[%pass (follow-wire gid host) %agent [host %pong] %watch [%table gid ~]]]
--
::
%-  agent:dbug
=|  state-2
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
  ::  %0 was the pre-seat lobby; nothing in it survives the change
  ?:  ?=([%0 *] q.old)  `this
  =/  prev  !<(versioned-state old)
  =?  prev  ?=(%1 -.prev)
    [%2 tables.prev ~ ~ ~ mirror.prev ~ invites.prev]
  ?>  ?=(%2 -.prev)
  =.  state  prev
  ::  (re)start the sweep if anyone is seated; a timer from before the
  ::  reload still fires, but the check on wake ignores it
  ?.  (any-seated tables)  `this(sweep ~)
  =^  cards  sweep  (arm now.bowl)
  [cards this]
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
      ?<  (~(has by tables) gid.act)
      =/  t=table:pong  [our.bowl ~ ~ ~ [0 0] now.bowl]
      :_  this(tables (~(put by tables) gid.act t), closed (~(del in closed) gid.act))
      (publish gid.act t)
    ::
        %challenge
      ?>  (gid-ok gid.act)
      ?<  (~(has by tables) gid.act)
      ?<  =(who.act our.bowl)
      =/  t=table:pong  [our.bowl `our.bowl ~ `who.act [0 0] now.bowl]
      =.  tables  (~(put by tables) gid.act t)
      =.  seen  (~(put by seen) [gid.act our.bowl] now.bowl)
      =^  more  sweep  ?^(sweep [~ sweep] (arm now.bowl))
      :_  this
      :(weld (publish gid.act t) ~[(send who.act [%invite gid.act])] more)
    ::
        %follow
      ?:  =(host.act our.bowl)
        =/  t  (~(get by tables) gid.act)
        ?~  t  [~[(give-gone gid.act)] this]
        [~[(give-table gid.act u.t)] this]
      ?>  (gid-ok gid.act)
      =/  m  (~(get by mirror) gid.act)
      ?^  m  [~[(give-table gid.act u.m)] this]
      ?:  (~(has by shut) gid.act)  [~[(give-gone gid.act)] this]
      [(follow bowl mirror gid.act host.act) this]
    ::
        %sit
      ?.  =(host.act our.bowl)
        ?>  (gid-ok gid.act)
        :_  this
        %+  snoc  (follow bowl mirror gid.act host.act)
        (send host.act [%sit gid.act side.act])
      =/  t  (~(get by tables) gid.act)
      ?~  t  [~[(give-note gid.act 'this table is closed')] this]
      =/  res  (sit u.t our.bowl side.act)
      ?:  ?=(%| -.res)  [~[(give-note gid.act p.res)] this]
      =.  tables  (~(put by tables) gid.act p.res)
      =.  seen  (~(put by seen) [gid.act our.bowl] now.bowl)
      =^  more  sweep  ?^(sweep [~ sweep] (arm now.bowl))
      [(weld (publish gid.act p.res) more) this]
    ::
        %stand
      ?.  =(host.act our.bowl)
        [~[(send host.act [%stand gid.act])] this]
      =/  t  (~(get by tables) gid.act)
      ?~  t  `this
      =/  new  (stand u.t our.bowl)
      :_  this(tables (~(put by tables) gid.act new))
      (publish gid.act new)
    ::
        %score
      ?.  =(host.act our.bowl)
        [~[(send host.act [%score gid.act l.act r.act])] this]
      =/  t  (~(get by tables) gid.act)
      ?~  t  `this
      ?~  (seated u.t our.bowl)  `this
      =/  new  u.t(score [l.act r.act])
      :_  this(tables (~(put by tables) gid.act new))
      (publish gid.act new)
    ::
        %here
      ?.  =(host.act our.bowl)
        [~[(send host.act [%here gid.act])] this]
      =/  t  (~(get by tables) gid.act)
      ?~  t  `this
      ?~  (seated u.t our.bowl)  `this
      `this(seen (~(put by seen) [gid.act our.bowl] now.bowl))
    ::
        %close
      ?.  (~(has by tables) gid.act)  `this
      ::  followers stay subscribed, so a reopen reaches them
      :_  this(tables (~(del by tables) gid.act), closed (~(put in closed) gid.act))
      :~  [%give %fact ~[[%table gid.act ~]] %pong-update !>(`update:pong`[%closed gid.act])]
          (give-gone gid.act)
      ==
    ::
        %dismiss
      =/  host  (~(get by invites) gid.act)
      =/  from=(unit @p)
        =/  m  (~(get by mirror) gid.act)
        ?^  m  `host.u.m
        (~(get by shut) gid.act)
      =/  cards=(list card)
        ;:  weld
          ?~(host ~ ~[(send u.host [%decline gid.act])])
          ?~(from ~ ~[[%pass (follow-wire gid.act u.from) %agent [u.from %pong] %leave ~]])
          ~[(give-gone gid.act)]
        ==
      :-  cards
      %=  this
        invites  (~(del by invites) gid.act)
        mirror   (~(del by mirror) gid.act)
        shut     (~(del by shut) gid.act)
      ==
    ::
        %relay
      ?.  (lte (met 3 body.act) max-body)  `this
      ?:  =(to.act our.bowl)
        [~[(give-relay gid.act our.bowl body.act)] this]
      [~[(send to.act [%relay gid.act body.act])] this]
    ==
  ::
      %pong-msg
    =/  =msg:pong  !<(msg:pong vase)
    =/  who=@p  src.bowl
    =/  =gid:pong  (msg-gid msg)
    ?-    -.msg
        %invite
      ?.  (gid-ok gid)  `this
      ?:  |((~(has by invites) gid) (~(has by tables) gid))  `this
      ?:  (gte ~(wyt by invites) max-invites)  `this
      :_  this(invites (~(put by invites) gid who))
      [(give-invite gid who) (follow bowl mirror gid who)]
    ::
        %decline
      =/  t  (~(get by tables) gid)
      ?~  t  `this
      ?.  =(invite.u.t `who)  `this
      =/  new  u.t(invite ~)
      :_  this(tables (~(put by tables) gid new))
      %+  snoc  (publish gid new)
      (give-note gid (crip "{(scow %p who)} declined"))
    ::
        %sit
      =/  t  (~(get by tables) gid)
      ?~  t  [~[(send who [%refuse gid 'this table is closed'])] this]
      =/  res  (sit u.t who side.msg)
      ?:  ?=(%| -.res)  [~[(send who [%refuse gid p.res])] this]
      =.  tables  (~(put by tables) gid p.res)
      =.  seen  (~(put by seen) [gid who] now.bowl)
      =^  more  sweep  ?^(sweep [~ sweep] (arm now.bowl))
      [(weld (publish gid p.res) more) this]
    ::
        %stand
      =/  t  (~(get by tables) gid)
      ?~  t  `this
      =/  new  (stand u.t who)
      ?:  =(new u.t)  `this
      :_  this(tables (~(put by tables) gid new))
      (publish gid new)
    ::
        %score
      =/  t  (~(get by tables) gid)
      ?~  t  `this
      ?~  (seated u.t who)  `this
      =/  new  u.t(score [l.msg r.msg])
      :_  this(tables (~(put by tables) gid new))
      (publish gid new)
    ::
        %here
      =/  t  (~(get by tables) gid)
      ?~  t  `this
      ?~  (seated u.t who)  `this
      `this(seen (~(put by seen) [gid who] now.bowl))
    ::
        %refuse
      =/  m  (~(get by mirror) gid)
      ?:  &(?=(^ m) !=(host.u.m who))  `this
      [~[(give-note gid why.msg)] this]
    ::
        %relay
      ?.  (lte (met 3 body.msg) max-body)  `this
      ?.  ?|  (~(has by tables) gid)
              (~(has by mirror) gid)
              (~(has by invites) gid)
          ==
        `this
      [~[(give-relay gid who body.msg)] this]
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
    =/  inv=(list json)
      %+  turn  ~(tap by invites)
      |=  [g=gid:pong h=@p]
      (pairs:enjs:format ~[['gid' s+g] ['host' s+(scot %p h)]])
    :_  this
    :~  :*  %give  %fact  ~  %json
            !>  ^-  json
            %-  pairs:enjs:format
            :~  ['our' s+(scot %p our.bowl)]
                ['tables' a+(turn ~(tap by (~(uni by mirror) tables)) table-json)]
                ['invites' a+inv]
            ==
        ==
    ==
  ::
      [%table @ ~]
    ::  anyone holding the gid may follow, open or closed; an unknown gid
    ::  nacks the watch
    =/  g=gid:pong  i.t.path
    =/  t  (~(get by tables) g)
    ?^  t
      :_(this ~[[%give %fact ~ %pong-update !>(`update:pong`[%table g u.t])]])
    ?.  (~(has in closed) g)  ~|(%no-such-table !!)
    :_(this ~[[%give %fact ~ %pong-update !>(`update:pong`[%closed g])]])
  ==
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  (on-peek:def path)
      [%x %tables ~]
    ``json+!>(`json`a+(turn ~(tap by (~(uni by mirror) tables)) table-json))
  ==
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+    wire  (on-agent:def wire sign)
      [%msg @ @ ~]
    ?.  ?=(%poke-ack -.sign)  `this
    ?~  p.sign  `this
    ::  a failed sit or invite is worth a line; a dropped relay is not
    ?.  ?=(?(%sit %invite) i.t.t.wire)  `this
    [~[(give-note i.t.wire 'their ship refused -- is %pong installed there?')] this]
  ::
      [%table @ @ ~]
    =/  =gid:pong  i.t.wire
    =/  host=@p  (slav %p i.t.t.wire)
    ?-    -.sign
        %poke-ack  `this
    ::
        %watch-ack
      ?~  p.sign  `this
      ::  no such table: never existed on its host
      :_  %=  this
            mirror   (~(del by mirror) gid)
            invites  (~(del by invites) gid)
            shut     (~(del by shut) gid)
          ==
      ~[(give-gone gid)]
    ::
        %kick
      ?.  ?|  (~(has by mirror) gid)
              (~(has by invites) gid)
              (~(has by shut) gid)
          ==
        `this
      [~[[%pass wire %agent [host %pong] %watch [%table gid ~]]] this]
    ::
        %fact
      ?.  =(%pong-update p.cage.sign)  `this
      =/  upd  !<(update:pong q.cage.sign)
      ?-    -.upd
          %table
        ?.  &(=(gid.upd gid) =(host.table.upd host))  `this
        :_  this(mirror (~(put by mirror) gid table.upd), shut (~(del by shut) gid))
        ~[(give-table gid table.upd)]
      ::
          %closed
        ?.  =(gid.upd gid)  `this
        :_  this(mirror (~(del by mirror) gid), shut (~(put by shut) gid host))
        ~[(give-gone gid)]
      ==
    ==
  ==
::
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?+    wire  (on-arvo:def wire sign-arvo)
      [%eyre-bind ~]  `this
  ::
      [%sweep ~]
    ::  only the latest timer counts; one left over from a reload is ignored.
    ::  test a copy: narrowing sweep itself would forbid resetting it to ~
    =/  due=(unit @da)  sweep
    ?.  ?&(?=(^ due) (gte now.bowl u.due))  `this
    =.  sweep  ~
    =.  seen  (prune now.bowl tables seen)
    =/  changed=(list [gid:pong table:pong])
      %+  murn  ~(tap by tables)
      |=  [g=gid:pong t=table:pong]
      ^-  (unit [gid:pong table:pong])
      =/  n  (evict now.bowl seen g t)
      ?:(=(n t) ~ `[g n])
    =.  tables  (~(gas by tables) changed)
    =.  seen  (prune now.bowl tables seen)
    =/  cards=(list card)  (zing (turn changed publish))
    ?.  (any-seated tables)  [cards this]
    =^  more  sweep  (arm now.bowl)
    [(weld cards more) this]
  ==
::
++  on-leave  on-leave:def
++  on-fail   on-fail:def
--
