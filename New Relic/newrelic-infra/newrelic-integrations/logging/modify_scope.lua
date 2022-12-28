function modify_scope(tag, timestamp, record)
  local scope = record["scope"]
  local modified = 0
  if scope ~= nil then
--  if scope:find("NR_LINKING") then -- doesn't work bacause scop is an object (table)
-- [("NR_LINKING": "NR-LINKING|MzI5MzIwMHxBUE18QVBQTElDQVRJT058NDY1NTA4OTAw|WEBAPP|||SalesRunApp|")]
    if string.find(scope, "NR_LINKING") then
	  record["scope"] = "NR_LINKING"
	  modified = 2
	end
  end
  return modified, timestamp, record
end

