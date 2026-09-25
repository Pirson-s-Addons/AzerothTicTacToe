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

**Azeroth TicTacToe** lets you challenge another player who also has the addon to classic Tic-Tac-Toe with moving pieces, optionally with a bet in gold, silver or copper. Wins, losses, debts and the match history are saved between sessions.

## Rules

- Each player has **3 pieces**. First you take turns placing them.
- Once both have their 3 pieces on the board, each turn you **move one of your pieces** to a free square next to it, along a line (row, column or diagonal).
- The first to make **3 in a row** wins. There are no draws by themselves: the game goes on until someone wins.
- A **coin toss** decides who starts.
- If a player does not move within **5 minutes** (disconnected or away), the game expires: nobody wins or loses. The board shows the countdown of the opponent's turn.

## Features

- Challenge anyone with the addon, with or without a bet in **gold, silver and copper**.
- 3x3 board in its own window; moves travel as addon messages, and every incoming move is checked against the rules (right opponent, right turn, legal move).
- **Surrender** button: ends the game as a defeat (it asks first). Closing the board only hides it.
- **Draw** button: shows "Draw", "Draw 1/2" and "Draw 2/2". Only when both players press it the game ends with nobody winning or losing.
- Only the two players in the game can move, surrender or agree a draw.
- **Ledger** with the ranking, the gold each player owes you and the match history.
- **Collect** button on every debt in your favor: target the player and click it to open the trade window (WoW only lets addons open a trade from a click).
- **Paid** button on every debt: it does not delete anything, it asks the other player to confirm. The debt leaves both ledgers only when they type `/ttt accept paid`; with `/ttt cancel paid` it stays in both.
- Minimap icon: left click opens the Ledger, right click shows or hides the board.
- **Options → AddOns → Azeroth TicTacToe**: an About page with the rules, links and commands, and a **General** page with minimap button, sounds, accept challenges and board size.
- Translated into 20 languages.

## Installation

1. Download the zip from the [latest release](https://github.com/Pirson-s-Addons/AzerothTicTacToe/releases/latest).
2. Extract the `AzerothTicTacToe` folder into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Restart WoW and enable the addon.

It only loads on WoW Forever: the only TOC is `AzerothTicTacToe_Camelot.toc` (`Camelot` is Forever's game type), so no other client lists it. Both players need the addon.

## Usage

Commands follow your client's language (for example `/ttt aceptar` in Spanish); the English ones always work too.

- `/ttt` opens the options and lists the commands in the chat.
- `/ttt <player> [gold] [silver] [copper]` challenges a player, optionally with a bet: `/ttt Caudillo Jr 0 0 10` bets 10 copper.
- `/ttt accept` / `/ttt cancel` accepts or declines the pending challenge.
- `/ttt accept paid` / `/ttt cancel paid` confirms or denies that a debt has been paid.

---

## 🇪🇸 Español

**Azeroth TicTacToe** te deja retar a otro jugador que también tenga el addon al 3 en raya clásico, con fichas que se mueven y apuesta en oro, plata o cobre si quieres. Victorias, derrotas, deudas y el historial de partidas se guardan entre sesiones.

### Reglas

- Cada jugador tiene **3 fichas**. Primero se colocan por turnos.
- Cuando los dos tienen sus 3 fichas en el tablero, en cada turno **mueves una de tus fichas** a una casilla libre de al lado, siguiendo una línea (fila, columna o diagonal).
- Gana el primero que hace **3 en raya**. No hay empate por sí solo: la partida sigue hasta que alguien gana.
- Quién empieza se decide **a cara o cruz**.
- Si un jugador no mueve en **5 minutos** (desconectado o ausente), la partida caduca: nadie gana ni pierde. El tablero muestra la cuenta atrás del turno del rival.

### Funciones

- Reta a cualquiera que tenga el addon, con o sin apuesta en **oro, plata y cobre**.
- Tablero 3x3 en su propia ventana; las jugadas viajan como mensajes de addon y cada jugada que llega se comprueba con las reglas (rival correcto, su turno, jugada válida).
- Botón **Rendirse**: termina la partida como derrota (pide confirmación). Cerrar el tablero solo lo oculta.
- Botón **Tablas**: muestra "Tablas", "Tablas 1/2" y "Tablas 2/2". Solo cuando lo pulsan los dos jugadores la partida acaba sin que nadie gane ni pierda.
- Solo los dos jugadores de la partida pueden mover, rendirse o pedir tablas.
- **Libro de cuentas** con el ranking, el oro que te debe cada jugador y el historial de partidas.
- Botón **Cobrar** en cada deuda a tu favor: selecciona al jugador y púlsalo para abrir el comercio (WoW solo deja a un addon abrir un comercio desde un clic).
- Botón **Pagado** en cada deuda: no borra nada, pide al otro jugador que lo confirme. La deuda sale de los dos libros solo cuando el otro escribe `/ttt aceptar pagado`; con `/ttt cancelar pagado` se queda en los dos.
- Icono de minimapa: clic izquierdo abre el Libro de cuentas, clic derecho muestra u oculta el tablero.
- **Opciones → AddOns → Azeroth TicTacToe**: página Acerca de con las reglas, enlaces y comandos, y página **General** con botón del minimapa, sonidos, aceptar retos y tamaño del tablero.
- Traducido a 20 idiomas.

### Instalación

1. Descarga el zip de la [última release](https://github.com/Pirson-s-Addons/AzerothTicTacToe/releases/latest).
2. Extrae la carpeta `AzerothTicTacToe` en `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Reinicia el juego y activa el addon.

Solo se carga en WoW Forever: su único `.toc` es `AzerothTicTacToe_Camelot.toc` (`Camelot` es el game type de Forever), así que ningún otro cliente lo muestra. Los dos jugadores necesitan el addon.

### Uso

Los comandos van en el idioma de tu cliente; los de inglés (`accept`, `cancel`, `paid`) valen siempre.

- `/ttt` abre las opciones y muestra los comandos en el chat.
- `/ttt <jugador> [oro] [plata] [cobre]` reta a un jugador, con apuesta opcional: `/ttt Caudillo Jr 0 0 10` apuesta 10 de cobre.
- `/ttt aceptar` / `/ttt cancelar` acepta o rechaza el reto pendiente.
- `/ttt aceptar pagado` / `/ttt cancelar pagado` confirma o niega que una deuda se ha pagado.
