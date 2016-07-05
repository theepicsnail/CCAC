pprint = dofile("/craft/pretty_print.lua")
HEADER = 'dofile("/craft/craft_pattern.lua"){\n'
FOOTER = '})'
INGREDIENT = '{%u,%u,%u,%q},\n'


print("Place pattern in top left 3x3")
print("Resources will be consumed.")
print("Press enter when ready")
read()

function fixName(name)
  return string.gsub(name,":","_")
end

function formatIngredient(pos, item)
  return string.format(
      INGREDIENT,
      pos,
      item["count"],
      item["damage"],
      fixName(item["name"]))
end


pattern = HEADER
for i=1,12 do
  if i%4 then
    details = turtle.getItemDetail(i)
    if details then
      pattern = pattern .. formatIngredient(i, details)
    end
  end
end
pattern = pattern .. FOOTER

print(pattern)
read()
