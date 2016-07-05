wb = dofile('/craft/workbench.lua')

function serialize(t)
  if type(t) == 'table' then
    local out = ""
    for k,v in pairs(t) do
      local ks = string.gsub(serialize(k),"\n", "\n  ")
      local vs = string.gsub(serialize(v),"\n", "\n  ")
      out=out..string.format("  [%q]=%s,\n", ks, vs)
    end
    return "{\n"..out.."}"
  else
    return tostring(t)
  end
end
function dump(t)
  local data = serialize(t)
  f = fs.open("out","w")
  f.write(data)
  f.close()
end

dump({
 wb.planCrafting(
  {
--  ['minecraft:planks']=3,
--  ['minecraft:log']=1,
  }, 
  'minecraft_crafting_table')
})

