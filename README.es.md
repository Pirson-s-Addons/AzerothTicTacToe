<h1 align="center">Azeroth TicTacToe</h1>

<p align="center">
  <b>Juega al 3 en raya contra otro jugador dentro del juego, apostando oro, con clasificación permanente, para World of Warcraft: Forever</b>
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
<a href="README.md">🇬🇧 English</a>
</p>

---

## 📸 Capturas

<table>
<tr>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/705/tablero-apuestas-png.png" alt="Betting"><br><sub>Apuesta</sub></td>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/709/tablero-png.png" alt="Game board"><br><sub>Tablero</sub></td>
</tr>
<tr>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/704/tablero-1-png.png" alt="A win"><br><sub>Partida ganada</sub></td>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/707/options-menu-png.png" alt="Options"><br><sub>Opciones</sub></td>
</tr>
<tr>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/706/options-menu-config-png.png" alt="Settings"><br><sub>Ajustes</sub></td>
</tr>
</table>

---

## Qué hace

**Azeroth TicTacToe** te deja retar a otro jugador que también tenga el addon al 3 en raya clásico, con fichas que se mueven y apuesta en oro, plata o cobre si quieres. Victorias, derrotas, deudas y el historial de partidas se guardan entre sesiones.

## Reglas

- Cada jugador tiene **3 fichas**. Primero se colocan por turnos.
- Cuando los dos tienen sus 3 fichas en el tablero, en cada turno **mueves una de tus fichas** a una casilla libre de al lado, siguiendo una línea (fila, columna o diagonal).
- Gana el primero que hace **3 en raya**. No hay empate por sí solo: la partida sigue hasta que alguien gana.
- Quién empieza se decide **a cara o cruz**.
- Si un jugador no mueve en **5 minutos** (desconectado o ausente), la partida caduca: nadie gana ni pierde. El tablero muestra la cuenta atrás del turno del rival.

## Funciones

- Reta a cualquiera que tenga el addon, con o sin apuesta en **oro, plata y cobre**.
- Tablero 3x3 en su propia ventana; las jugadas viajan como mensajes de addon y cada jugada que llega se comprueba con las reglas (rival correcto, su turno, jugada válida).
- Botón **Rendirse**: termina la partida como derrota (pide confirmación). Cerrar el tablero solo lo oculta.
- Botón **Tablas**: muestra "Tablas", "Tablas 1/2" y "Tablas 2/2". Solo cuando lo pulsan los dos jugadores la partida acaba sin que nadie gane ni pierda.
- Solo los dos jugadores de la partida pueden mover, rendirse o pedir tablas.
- Botón **Revancha** al acabar la partida: reta otra vez al mismo jugador por la misma apuesta. El otro ve "Aceptar revancha" en su propio tablero y acepta con un clic.
- **Libro de Cuentas Goblin** con cuatro pestañas: **Ranking** (victorias y derrotas de cada uno de tus personajes), **Rivales** (tus victorias, derrotas, tablas y dinero ganado o perdido contra cada jugador), **Deudas** e **Historial** (tus últimas 50 partidas). Si lo abres con un jugador seleccionado, su nombre ya viene puesto para retarle.
- Botón **Cobrar** en cada deuda a tu favor: selecciona al jugador y púlsalo para abrir el comercio (WoW solo deja a un addon abrir un comercio desde un clic).
- Botón **Pagado** en cada deuda: no borra nada, pide al otro jugador que lo confirme. La deuda sale de los dos libros solo cuando el otro escribe `/ttt aceptar pagado`; con `/ttt cancelar pagado` se queda en los dos.
- Icono de minimapa: clic izquierdo abre el Libro de cuentas, clic derecho muestra u oculta el tablero.
- **Opciones → AddOns → Azeroth TicTacToe**: página Acerca de con las reglas, enlaces y comandos, y página **General** con botón del minimapa, sonidos, aceptar retos y tamaño del tablero.
- Traducido a 20 idiomas.

## Instalación

Instálalo desde [CurseForge](https://www.curseforge.com/wow/addons/azeroth-tic-tac-toe), o a mano:

1. Descarga el zip de la [última release](https://github.com/Pirson-s-Addons/AzerothTicTacToe/releases/latest).
2. Extrae la carpeta `AzerothTicTacToe` en `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Reinicia el juego y activa el addon.

Solo se carga en WoW Forever: su único `.toc` es `AzerothTicTacToe_Camelot.toc` (`Camelot` es el game type de Forever), así que ningún otro cliente lo muestra. Los dos jugadores necesitan el addon.

## Uso

Los comandos van en el idioma de tu cliente; los de inglés (`accept`, `cancel`, `paid`) valen siempre.

- `/ttt` abre las opciones y muestra los comandos en el chat.
- `/ttt <jugador> [oro] [plata] [cobre]` reta a un jugador, con apuesta opcional: `/ttt Caudillo Jr 0 0 10` apuesta 10 de cobre.
- `/ttt aceptar` / `/ttt cancelar` acepta o rechaza el reto pendiente.
- `/ttt aceptar pagado` / `/ttt cancelar pagado` confirma o niega que una deuda se ha pagado.

---

**Autor**: Pirson · [GitHub](https://github.com/Pirson-s-Addons) · [CurseForge](https://www.curseforge.com/members/pirson/projects) · Licencia MIT
