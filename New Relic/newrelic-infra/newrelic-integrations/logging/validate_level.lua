function validate_level(tag, timestamp, record)
   local level = record["level"]
   local modified = 0
   if level ~= nil then
      if level == "INF" then
         record["level"] = "INFO"
		 modified = 2
      elseif level == "ERR" then
         record["level"] = "ERROR"
	     modified = 2
      elseif level == "WRN" then
         record["level"] = "WARN"
		 modified = 2
      end
   end
   return modified, timestamp, record
end
