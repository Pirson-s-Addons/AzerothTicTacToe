<p align="center"><a href="https://www.curseforge.com/wow/addons/azeroth-tic-tac-toe"><img src="https://raw.githubusercontent.com/Pirson-s-Addons/.github/main/profile/assets/readme-tt-en.svg" width="100%" alt="Azeroth Tic-Tac-Toe"/></a></p>

<p align="center"><b>English</b> · <a href="README.es.md">Español</a></p>

<p align="center">
<a href="https://www.curseforge.com/wow/addons/azeroth-tic-tac-toe"><b>CurseForge</b></a> ·
<a href="https://github.com/Pirson-s-Addons/AzerothTicTacToe/releases/latest"><b>Download</b></a>
</p>

## Screenshots

<table>
<tr>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/709/tablero-png.png" alt="Game board"><br><sub>Game board</sub></td>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/704/tablero-1-png.png" alt="A win"><br><sub>A win</sub></td>
</tr>
<tr>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/2026/904/screenshot_1-png.png" alt="Challenge someone, betting gold"><br><sub>Challenge someone, betting gold</sub></td>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/2026/903/screenshot_2-png.png" alt="Your record against each player"><br><sub>Your record against each player</sub></td>
</tr>
<tr>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/2026/902/screenshot_3-png.png" alt="Who owes whom"><br><sub>Who owes whom</sub></td>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/2026/901/screenshot_4-png.png" alt="Your last 50 games"><br><sub>Your last 50 games</sub></td>
</tr>
<tr>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/707/options-menu-png.png" alt="Options"><br><sub>Options</sub></td>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/706/options-menu-config-png.png" alt="Settings"><br><sub>Settings</sub></td>
</tr>
</table>

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
- No one to play with? **vs Azeroth AI** (on the board and in the Ledger) starts a game against the computer. No bet: it counts in History and Rivals, not in the Ranking.
- 3x3 board in its own window; moves travel as addon messages, and every incoming move is checked against the rules (right opponent, right turn, legal move).
- **Surrender** button: ends the game as a defeat (it asks first). Closing the board only hides it.
- **Draw** button: shows "Draw", "Draw 1/2" and "Draw 2/2". Only when both players press it the game ends with nobody winning or losing.
- Only the two players in the game can move, surrender or agree a draw.
- **Rematch** button when the game ends: it challenges the same player again for the same bet. The other player sees "Accept rematch" on their own board and accepts with one click.
- **Goblin Ledger** with four tabs: **Ranking** (wins and losses of each of your characters), **Rivals** (your wins, losses, draws and money won or lost against each player), **Debts** and **History** (your last 50 games). Opening it with a player targeted fills in their name to challenge them.
- **Collect** button on every debt in your favor: target the player and click it to open the trade window (WoW only lets addons open a trade from a click).
- **Paid** button on every debt: it does not delete anything, it asks the other player to confirm. The debt leaves both ledgers only when they type `/ttt accept paid`; with `/ttt cancel paid` it stays in both.
- Minimap icon: left click opens the Ledger, right click shows or hides the board.
- **Options → AddOns → Azeroth TicTacToe**: an About page with the rules, links and commands, and a **General** page with minimap button, sounds, accept challenges and board size.
- Translated into 20 languages.

## Usage

Commands follow your client's language (for example `/ttt aceptar` in Spanish); the English ones always work too.

- `/ttt` opens the options and lists the commands in the chat.
- `/ttt <player> [gold] [silver] [copper]` challenges a player, optionally with a bet: `/ttt Caudillo Jr 0 0 10` bets 10 copper.
- `/ttt ai` starts a game against Azeroth AI, the computer.
- `/ttt accept` / `/ttt cancel` accepts or declines the pending challenge.
- `/ttt accept paid` / `/ttt cancel paid` confirms or denies that a debt has been paid.

## Installation

Install it from [CurseForge](https://www.curseforge.com/wow/addons/azeroth-tic-tac-toe), or by hand:

1. Download the zip from the [latest release](https://github.com/Pirson-s-Addons/AzerothTicTacToe/releases/latest).
2. Extract the `AzerothTicTacToe` folder into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Restart WoW and enable the addon.

It only loads on WoW Forever: the only TOC is `AzerothTicTacToe_Camelot.toc` (`Camelot` is Forever's game type), so no other client lists it. Both players need the addon.

## For addon authors

<details>
<summary><b>Public API</b></summary>

Global `AzerothTicTacToeAPI` (`version = 1`):

- `AzerothTicTacToeAPI.PlayVsAI()` opens the board against Azeroth AI. Returns `false` if a game is already in progress.
- `AzerothTicTacToeAPI.IsPlaying()` returns `true` during a game.

Check `AzerothTicTacToeAPI.version == 1` before using it.
</details>

<br/>

<p align="center"><a href="https://github.com/Pirson-s-Addons"><img src="https://raw.githubusercontent.com/Pirson-s-Addons/.github/main/profile/assets/readme-footer-en.svg" width="100%" alt="Part of Pirson's Addons. See all addons."/></a></p>
