pprint = dofile("/craft/pretty_print.lua")
return function(pattern)
  pprint("Pattern")
  pprint(pattern)
end
