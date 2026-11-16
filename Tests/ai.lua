-- Comprobacion de Core/AI.lua fuera del juego (ver Tests/run.py)
local ns = {}
assert(loadfile("Core/AI.lua"))("AzerothTicTacToe", ns)

-- Copia de ADJACENT y PIECES de Core/AzerothTicTacToe.lua
local ADJ = {
    [1] = { [2] = true, [4] = true, [5] = true }, [2] = { [1] = true, [3] = true, [5] = true },
    [3] = { [2] = true, [5] = true, [6] = true }, [4] = { [1] = true, [5] = true, [7] = true },
    [5] = { [1] = true, [2] = true, [3] = true, [4] = true, [6] = true, [7] = true, [8] = true, [9] = true },
    [6] = { [3] = true, [5] = true, [9] = true }, [7] = { [4] = true, [5] = true, [8] = true },
    [8] = { [5] = true, [7] = true, [9] = true }, [9] = { [5] = true, [6] = true, [8] = true },
}
local function Board(h, a)
    local b = { "", "", "", "", "", "", "", "", "" }
    for _, i in ipairs(h) do b[i] = "Horde" end
    for _, i in ipairs(a) do b[i] = "Alliance" end
    return b
end
local sure = function(n) return n and 1 or 0.99 end -- sin despiste, la primera de las mejores

-- Coloca la tercera y gana (aunque el rival amenace 3)
local from, to = ns.AIMove(Board({ 1, 2 }, { 4, 5 }), "Alliance", "Horde", ADJ, 3, sure)
assert(from == nil and to == 6, "gana al colocar: " .. tostring(to))
-- Bloquea al colocar
from, to = ns.AIMove(Board({ 1, 2 }, { 5 }), "Alliance", "Horde", ADJ, 3, sure)
assert(from == nil and to == 3, "bloquea: " .. tostring(to))
-- Gana moviendo 6 -> 3
from, to = ns.AIMove(Board({ 4, 5, 8 }, { 1, 2, 6 }), "Alliance", "Horde", ADJ, 3, sure)
assert(from == 6 and to == 3, "gana moviendo: " .. tostring(from) .. "->" .. tostring(to))
-- Con despiste tampoco deja escapar la victoria
from, to = ns.AIMove(Board({ 4, 5, 8 }, { 1, 2, 6 }), "Alliance", "Horde", ADJ, 3, function(n) return n and 1 or 0 end)
assert(from == 6 and to == 3, "despiste no tira la victoria")

-- IA contra IA: todas las jugadas legales hasta 200 turnos
math.randomseed(7)
for game = 1, 30 do
    local b, turn, other = Board({}, {}), "Horde", "Alliance"
    for _ = 1, 200 do
        local count = 0
        for i = 1, 9 do if b[i] == turn then count = count + 1 end end
        local f, t = ns.AIMove(b, turn, other, ADJ, 3)
        assert(t and b[t] == "", "destino libre")
        if count < 3 then assert(f == nil, "coloca") else assert(b[f] == turn and ADJ[f][t], "mueve contigua") end
        if f then b[f] = "" end
        b[t] = turn
        if ns.AIWinner(b) then break end
        turn, other = other, turn
    end
end
print("OK")
