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
<a href="README.es.md">🇪🇸 Español</a>
</p>

---

## 📸 Screenshots

<table>
<tr>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/705/tablero-apuestas-png.png" alt="Betting"><br><sub>Betting</sub></td>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/709/tablero-png.png" alt="Game board"><br><sub>Game board</sub></td>
</tr>
<tr>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/704/tablero-1-png.png" alt="A win"><br><sub>A win</sub></td>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/707/options-menu-png.png" alt="Options"><br><sub>Options</sub></td>
</tr>
<tr>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/706/options-menu-config-png.png" alt="Settings"><br><sub>Settings</sub></td>
</tr>
</table>

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

Install it from [CurseForge](https://www.curseforge.com/wow/addons/azeroth-tic-tac-toe), or by hand:

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

**Author**: Pirson · [GitHub](https://github.com/Pirson-s-Addons) · [CurseForge](https://www.curseforge.com/members/pirson/projects) · MIT License
