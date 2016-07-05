
print "PPrint loaded"
function serialize (o,write,indent)
  indent = indent or ""
  write = write or io.write
  
  if type(o) == "number" then
    write(o)
  elseif type(o) == "string" then
    write(string.format("%q", o))
  elseif type(o) == "table" then
    write("{\n")
    for k,v in pairs(o) do
      write(indent .. "  [")
      serialize(k, write)
      write("] = ")
      serialize(v, write, indent .. "  ")
      write(",\n")
    end
    write(indent.."}")
  else
    error("cannot serialize a " .. type(o))
  end
end
return serialize
