<h1 align="center">Azeroth TicTacToe</h1>

<p align="center">
  <b>Play Tic-Tac-Toe against another player inside the game, betting gold, with a persistent ranking, for World of Warcraft: Forever</b>
</p>

<p align="center">
<a href="https://github.com/Pirson-s-Addons/AzerothTicTacToe/releases/latest">
<img src="https://img.shields.io/github/v/release/Pirson-s-Addons/AzerothTicTacToe?style=for-the-badge&color=A78BFA">
</a>
<img src="https://img.shields.io/badge/WoW_Forever-1.60.1-C4B5FD?style=for-the-badge">
<a href="LICENSE">
<img src="https://img.shields.io/badge/License-MIT-E9D5FF?style=for-the-badge">
</a>
</p>

<p align="center">
<a href="#-español">🇪🇸 Español</a>
</p>

---

## What it does

**Azeroth TicTacToe** lets you challenge another player who also has the addon to a game of Tic-Tac-Toe, optionally with a gold bet. Wins, losses, gold debts and the match history are saved between sessions.

## Features

- Challenge anyone with the addon, with or without a **gold bet**.
- 3x3 board in its own window; moves travel as addon messages, and every incoming move is checked (right opponent, right turn, free square).
- **Ledger** with the ranking, the gold each player owes you and the match history.
- **Collect** button on every debt in your favor: target the player and click it to open the trade window (WoW only lets addons open a trade from a click).
- Minimap icon: left click opens the Ledger, right click shows or hides the board.
- Translated into 20 languages.

## Installation

1. Download the zip from the [latest release](https://github.com/Pirson-s-Addons/AzerothTicTacToe/releases/latest).
2. Extract the `AzerothTicTacToe` folder into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Restart WoW and enable the addon.

It only loads on WoW Forever: the only TOC is `AzerothTicTacToe_Camelot.toc` (`Camelot` is Forever's game type), so no other client lists it. Both players need the addon.

## Usage

- `/ttt` shows the list of commands.
- `/ttt <player> [gold]` challenges a player, optionally for a gold bet.
- `/ttt accept` / `/ttt cancel` accepts or declines the pending challenge.

---

## 🇪🇸 Español

**Azeroth TicTacToe** te deja retar a otro jugador que también tenga el addon a una partida de 3 en raya, con apuesta de oro si quieres. Victorias, derrotas, deudas de oro y el historial de partidas se guardan entre sesiones.

### Funciones

- Reta a cualquiera que tenga el addon, con o sin **apuesta de oro**.
- Tablero 3x3 en su propia ventana; las jugadas viajan como mensajes de addon y cada jugada que llega se comprueba (rival correcto, su turno, casilla libre).
- **Libro de cuentas** con el ranking, el oro que te debe cada jugador y el historial de partidas.
- Botón **Cobrar** en cada deuda a tu favor: selecciona al jugador y púlsalo para abrir el comercio (WoW solo deja a un addon abrir un comercio desde un clic).
- Icono de minimapa: clic izquierdo abre el Libro de cuentas, clic derecho muestra u oculta el tablero.
- Traducido a 20 idiomas.

### Instalación

1. Descarga el zip de la [última release](https://github.com/Pirson-s-Addons/AzerothTicTacToe/releases/latest).
2. Extrae la carpeta `AzerothTicTacToe` en `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Reinicia el juego y activa el addon.

Solo se carga en WoW Forever: su único `.toc` es `AzerothTicTacToe_Camelot.toc` (`Camelot` es el game type de Forever), así que ningún otro cliente lo muestra. Los dos jugadores necesitan el addon.

### Uso

- `/ttt` muestra la lista de comandos.
- `/ttt <jugador> [oro]` reta a un jugador, con apuesta de oro opcional.
- `/ttt accept` / `/ttt cancel` acepta o rechaza el reto pendiente.
