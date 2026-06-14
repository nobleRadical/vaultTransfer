-- Edit this.
-- Type the side of the computer 
-- that the IO chest is on, or its name if on a network.
IO_Chest = "minecraft:barrel_0"

--don't edit the rest of this.
ku = require "kasutils"
cc = require "cc.completion"


ioc_name = IO_Chest
ioc = peripheral.wrap(ioc_name)

item_vault = peripheral.find("create:item_vault") or
    peripheral.find("create_connected:item_silo")
item_vault_name = peripheral.getName(vault)

if (not ioc or not item_vault) then
    printError("Can't find vault and chest. \
Either they are missing or the program isn't configured correctly. \
Open the program with 'edit transfer' and check that the variable \
at the top of the program are correct.")
sleep(2)
end

-- the generic vault
--These function's contracts (signatures, in other languages)
--should not change, but the contents may. 
vault = {
list = function()
-- returns list of items like inventory.list()
    return item_vault.list()
end,
vaultToIOC = function(fromSlot, amt, toSlot) -- amt and toSlot are nullable
-- returns number of items transferred
    return item_vault.pushItems(ioc_name, fromSlot, amt, toSlot)
end,
IOCToVault = function(fromSlot, amt, toSlot) -- amt and toSlot are nullable
-- returns number of items transferred
    return item_vault.pullItems(ioc_name, fromSlot, amt, toSlot)
end,
size = function()
    return item_vault.size()
end
}


function CLI()
term.clear()
term.setCursorPos(1,1)
print"Welcome to the storage transfer program."
while true do
    --CLI and arg dispatch
    print("")
    print("Vault has "..getNumItems(vault).."/"..(vault.size()*64).." items.")
    print("IO chest has "..getNumItems(ioc).."/"..(ioc.size()*64).." items.")
    print("Options:")
ku.colorWrite("(d)ump",colors.blue) print" into Vault"
ku.colorWrite("(s)earch",colors.white) print" from Vault"
ku.colorWrite("(l)ist",colors.lightBlue) print" items in vault"
ku.colorWrite("e(m)pty",colors.orange) print" vault into IO Chest"
ku.colorWrite("(e)xit",colors.red) print""
    ku.colorPrint(">",colors.cyan)
    local _, inStr = os.pullEvent("char")
    inStr = string.lower(inStr)
    if (inStr=="d") then
        dump()
    elseif (inStr=="s") then
        search()
    elseif (inStr=="l") then
        list()
    elseif (inStr=="m") then
        empty()
    elseif (inStr=="e") then
        return
    else
    end
end
end
 
function dump()
    for slot,item in pairs(ioc.list()) do
        local numtr = vault.IOCToVault(slot)
        if (numtr<1) then 
            printError("Dump Transfer Failure | slot"..slot) 
        else 
            print("Dumped "..numtr.." "..item.name.." from slot "..slot) 
        end
    end
end
 
function search(bDisplayName)
local search_index = {}
    -- "completion function" for read hack
    function _compPrint(read_buffer, cur)
        local out_name = nil
        term.clear()
        
        --header (read buffer)
        term.setCursorPos(1,1)
        if (not cur) then write(">") end
        write(read_buffer)
        --search list (limit 15 items)
        term.setCursorPos(1,2)
        local i = 1
        for k,v in pairs(search_index) do
            if (string.sub(k,1,string.len(read_buffer))==read_buffer
            or string.sub(k,-string.len(read_buffer))==read_buffer) then
                --name starts with read buffer: match
                if (cur==i) then
                    out_name = k
                    local item = vault.getItemDetail(v.instances[1].slot)
                    ku.colorWrite("> "..i.." ",colors.white)
                    write(k)
                    ku.colorPrint(" "..v.count,colors.lightGray)
                    ku.colorWrite("    "..item.displayName,colors.lightBlue)
                    ku.colorPrint(" | nbt: "..(v.nbt or "--"),colors.lightBlue)
                else
                    ku.colorWrite(" "..i.." ",colors.gray)
                    write(k)
                    ku.colorPrint(" "..v.count,colors.lightGray)
                end
                i = i + 1
            end
            if (i>15) then break end
        end
        --footer
        local maxX,maxY = term.getSize()
        term.setCursorPos(1,maxY)
        if (cur) then write("[^/down] Navigate [->/Enter] Select [<-] Exit") end
        return out_name,i-1
    end
    
_index(search_index, bDisplayName)

local prev_query = nil
    --read hack: completion function
    local query = read(nil, nil, _compPrint, prev_query) 
    cur = 1
    while true do    
        local sel, cur_max = _compPrint(query,cur)
        --event handling
        local event, key = os.pullEvent("key")
        if (key==keys.right or 
            key==keys.enter or 
            key==keys.numPadEnter) then
            while true do
                --deal with how many items & such
                term.clear()
                term.setCursorPos(1,1)
                local v = search_index[sel]
                local item = vault.getItemDetail(v.instances[1].slot)
                ku.colorWrite("> "..cur.." ",colors.white)
                write(sel)
                ku.colorPrint(" "..v.count,colors.lightGray)
                ku.colorWrite("    "..item.displayName,colors.lightBlue)
                ku.colorPrint(" | nbt: "..(v.nbt or "--"),colors.lightBlue)
                write("How many do you want (default 64): ")
                local num = read()
                if(tonumber(num)) then
                    _search_take(search_index, sel, num)
                    return
                else
                    _search_take(search_index, sel, 64)
                    return
                end
            end
        elseif (key==keys.down) then
            cur = cur + 1
            if (cur>cur_max) then cur = 1 end
        elseif (key==keys.up) then
            cur = cur - 1
             if (cur<1) then cur = cur_max end
        elseif (key==keys.left) then
            break
        end
    end
end
 
function _search_take(idx_table, entry, count)
local count = tonumber(count)
local itr = 0 -- items transferred
for _, itable in pairs(idx_table[entry].instances) do
    local t_itr = 
    vault.pushItems(ioc_name,itable.slot,count-itr)
    itr = itr + t_itr
    print("Took "..t_itr.."/"..itable.count.." "..entry.." from slot "..itable.slot)
 
    if (itr>=count) then break end
end
print(itr.."/"..count.." items taken.")
end
 
-- index function for search
function _index(itable, bDisplayName)
for slot, item in pairs(vault.list()) do
    local mod, name = string.gmatch(item.name,
    "(.+):(.+)")()
    local entry_name = name
    if (bDisplayName) then
        item = vault.getItemDetail(slot)
        entry_name = item.displayName
    end
    if (itable[entry_name] and 
    itable[entry_name].mod~=mod) then
        entry_name = entry_name.."@"..mod
    end
    if (itable[entry_name] and 
    itable[entry_name].nbt~=item.nbt) then
        entry_name = entry_name.."_"..
        string.sub(item.nbt,1,3)
    end
    if (not itable[entry_name]) then
        --make a new entry
        itable[entry_name] = {
            ["mod"]=mod,
            ["nbt"]=item.nbt,
            ["count"]=item.count,
            ["instances"]={
                {             
                    ["slot"]=slot,
                    ["count"]=item.count
                }
            }
        }
        if (bDisplayName) then
            itable[entry_name].name = name
        end
    else
        table.insert(itable[entry_name].instances, 
        {
            ["slot"]=slot,
            ["count"]=item.count
        })
        itable[entry_name].count = itable[entry_name].count + item.count
    end    
end
end
 
function list()
--index and sort contents
local vl = vault.list()
local array_itable = {}
local itable = {}
print("Indexing...")
_index(itable, false)
print("Done.\nSorting...")
for k,v in pairs(itable) do
    v.name = k
    table.insert(array_itable,v)
end    
table.sort(array_itable,function(one,two) 
return one.count>two.count end)
print"Done."
print("Generating slot map...")
ku.colorPrint("# = empty",colors.white)
ku.colorPrint("# = <32 items",colors.green)
ku.colorPrint("# = <64 items",colors.orange)
ku.colorPrint("# = 64 items",colors.red)
ku.pause("[Ready. Press Any Key]")

for i=1,vault.size() do
    if (i%180==0) then ku.pause("[more]") end
    local c = colors.white
    if (vl[i]) then
        c = colors.green
        if (vl[i].count > 32) then
            c = colors.orange
        elseif (vl[i].count >=64) then
            c = colors.red
        end
        vl[i].color = c
    end
    ku.colorWrite(i.." ",c)
end
ku.pause()
print("\nPrinting items...")
for i,n in ipairs(array_itable) do
    ku.colorWrite(" "..i.." ",colors.gray)
    write(n.name)
    print(" amt:"..n.count)
    write("slots:")
    for _,v in pairs(n.instances) do
        ku.colorWrite(" "..v.slot,
        vl[v.slot].color or colors.white)
    end
    print("")
    if (i % 5 == 0) then
        ku.pause"[more]"
    end
end
end

function empty()
    print("Are you sure you want to do this? \
    Once started, there's no way to stop. \
    type \"EMPTY\" below to continue.")
    local strIn = read()
    if (strIn~="EMPTY") then return end
    printError("Emptying vault into IO chest.")
    for k,v in pairs(vault.list()) do
        local itr = 0
        repeat itr = vault.pushItems(ioc_name,k)
        if (itr==0) then
            print"No space. Retrying..."
            sleep(1)
        end
        until itr>0
    end
    print"Vault should be empty."
end


function take(count, item_name)
local itr = 0 -- items transferred
for slot, item in pairs(vault.list()) do
    local trunc = string.gsub(item.name, ".+:","",1) -- truncated item name
    if (item.name == item_name or trunc == item_name) then
        local t_itr = 
        vault.pushItems(ioc_name,slot,count-itr)
        itr = itr + t_itr
        print("Took "..t_itr.."/"..item.count.." "..item.name.." from slot "..slot)
    end
    if (itr>=count) then break end
end
print(itr.."/"..count.." items taken.")
end
 
function getNumItems(inv)
local total = 0
for slot, item in pairs(inv.list()) do
    total = total + item.count
end
return total
end
 
CLI()
