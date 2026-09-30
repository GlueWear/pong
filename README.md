# Pong

Ship-vs-ship Pong for Urbit. Two players, one ball, mouse-controlled paddles,
first to 11.

The app and desk are named `%pong`.

## Install

```
|install ~nolset %pong
```

Both players need `%pong` installed.

## Play

- **Standalone:** open `/apps/pong`, enter a ship to challenge, or practice
  against the CPU.
- **In Noltbook:** attach **Pong** to a note to drop a table. Anyone in the note
  can take the other paddle; the game plays inline in the note.

## How it works

- `app/pong.hoon` seats players and relays game messages between ships over
  Ames. It never sees the ball.
- `lib/pong/index.html` runs the game. The host is the left paddle. Each side
  decides hits and misses on its own paddle, and the ball's path between
  paddles is predicted on both sides, so play stays smooth with little traffic.
- Noltbook discovers the app through `/apps/pong/noltbook.json`. The manifest
  asks for the `media` permission because Noltbook only gives same-origin
  access to media frames, and the game needs it to reach its agent.
