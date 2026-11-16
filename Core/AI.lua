local _, ns = ...

-- ==========================================
-- RIVAL IA ("Azeroth AI")
-- ==========================================
-- Sin API del juego: solo el tablero, para poder probarlo fuera (Tests/ai.lua).
-- Minimax con poda alfa-beta a DEPTH jugadas. Las fichas se mueven y no hay
-- empate, así que la búsqueda necesita tope; al llegar a él puntúa las líneas.

local LINES = { { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 }, { 1, 4, 7 }, { 2, 5, 8 }, { 3, 6, 9 }, { 1, 5, 9 }, { 3, 5, 7 } }
local DEPTH = 4
local WIN = 100
-- shortcut: un solo nivel de dificultad (se equivoca a propósito el 20 % de las
-- veces que no puede ganar al momento); si lo piden, un selector Fácil/Normal/Difícil.
local MISTAKE = 0.2

local function Winner(board)
    for _, l in ipairs(LINES) do
        local a = board[l[1]]
        if a ~= "" and a == board[l[2]] and a == board[l[3]] then return a end
    end
end

-- Mismas reglas que IsLegalMove: colocar mientras no estén todas; luego mover
-- una ficha a una casilla libre contigua (la tabla de contiguas es simétrica)
local function Moves(board, who, adjacent, pieces)
    local count, list = 0, {}
    for i = 1, 9 do if board[i] == who then count = count + 1 end end
    for to = 1, 9 do
        if board[to] == "" then
            if count < pieces then
                list[#list + 1] = { to = to }
            else
                for from in pairs(adjacent[to]) do
                    if board[from] == who then list[#list + 1] = { from = from, to = to } end
                end
            end
        end
    end
    return list
end

local function Apply(board, who, m)
    if m.from then board[m.from] = "" end
    board[m.to] = who
end

local function Undo(board, who, m)
    board[m.to] = ""
    if m.from then board[m.from] = who end
end

-- Al llegar al tope: dos en línea con la tercera libre y el centro
local function Heuristic(board, me, rival)
    local score = 0
    for _, l in ipairs(LINES) do
        local mine, theirs, empty = 0, 0, 0
        for _, i in ipairs(l) do
            local c = board[i]
            if c == me then mine = mine + 1 elseif c == rival then theirs = theirs + 1 else empty = empty + 1 end
        end
        if empty == 1 and mine == 2 then score = score + 3 end
        if empty == 1 and theirs == 2 then score = score - 3 end
    end
    if board[5] == me then score = score + 1 elseif board[5] == rival then score = score - 1 end
    return score
end

-- Ganar antes vale más (WIN + profundidad que queda); perder antes, menos
local function Search(board, me, rival, turn, depth, alpha, beta, adjacent, pieces)
    local w = Winner(board)
    if w == me then return WIN + depth end
    if w == rival then return -WIN - depth end
    if depth == 0 then return Heuristic(board, me, rival) end
    local moves = Moves(board, turn, adjacent, pieces)
    if #moves == 0 then return 0 end
    local mine = turn == me
    local other = mine and rival or me
    local best = mine and -math.huge or math.huge
    for _, m in ipairs(moves) do
        Apply(board, turn, m)
        local s = Search(board, me, rival, other, depth - 1, alpha, beta, adjacent, pieces)
        Undo(board, turn, m)
        if mine then
            if s > best then best = s end
            if best > alpha then alpha = best end
        else
            if s < best then best = s end
            if best < beta then beta = best end
        end
        if alpha >= beta then break end
    end
    return best
end

-- La jugada de "me": from (nil al colocar) y to. random(n) elige entre las
-- mejores empatadas; random() decide el despiste. Por defecto, math.random.
function ns.AIMove(board, me, rival, adjacent, pieces, random)
    random = random or math.random
    local b = {}
    for i = 1, 9 do b[i] = board[i] end
    local moves, scores = Moves(b, me, adjacent, pieces), {}
    if #moves == 0 then return end
    local bestScore, best = -math.huge, {}
    for i, m in ipairs(moves) do
        Apply(b, me, m)
        scores[i] = Search(b, me, rival, rival, DEPTH - 1, -math.huge, math.huge, adjacent, pieces)
        Undo(b, me, m)
        if scores[i] > bestScore then
            bestScore, best = scores[i], { m }
        elseif scores[i] == bestScore then
            best[#best + 1] = m
        end
    end
    -- Despiste: nunca deja escapar una victoria inmediata ni regala una al rival
    if bestScore < WIN + DEPTH - 1 and random() < MISTAKE then
        local safe = {}
        for i, m in ipairs(moves) do
            if scores[i] > -WIN - (DEPTH - 2) then safe[#safe + 1] = m end
        end
        if #safe > 0 then best = safe end
    end
    local m = best[random(#best)]
    return m.from, m.to
end

ns.AIWinner = Winner
