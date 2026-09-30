# Pong

Ship-vs-ship Pong for Urbit. Two paddles, one ball, mouse control, first to 11.

The app and desk are named `%pong`.

## Install

```
|install ~nolset %pong
```

Anyone who wants to play or watch needs `%pong` installed.

## Play

- **In Noltbook:** attach **Pong** to a note to drop a table. The table lives on
  your ship, but you don't hold a paddle unless you take one. Anyone in the note,
  you included, can take an open paddle. First come, first served.
- **Watch:** when both paddles are taken, anyone else can click **Watch live**.
- **Standalone:** open `/apps/pong` to challenge a ship (you take the left
  paddle; the right one is saved for them) or to practice against the CPU.

A paddle is given up after 2 minutes without mouse or keyboard activity in the
Pong frame, with a warning first. If a player's page closes, the table's ship
frees the paddle after 90 seconds without a heartbeat.

If you have the same table open in several tabs, only one of them plays; the
others offer **Play here** to move the game over.

## How it works

- `app/pong.hoon` keeps the tables this ship hosts (who holds which paddle, and
  the score), follows tables hosted elsewhere, and passes messages between
  pages on different ships. It never sees the ball.
- `lib/pong/index.html` runs the game. The two players' browsers connect
  directly over a WebRTC data channel; their ships only carry the connection
  setup, and carry the game themselves if a direct connection can't be made.
  Watchers connect directly to a player's browser the same way.
- Each side decides hits and misses on its own paddle. The ball's path between
  paddles is predicted on both sides, so play stays smooth with little traffic.
- Noltbook discovers the app through `/apps/pong/noltbook.json`. The manifest
  asks for the `media` permission because Noltbook only gives same-origin
  access to media frames, and the game needs it to reach its agent.
