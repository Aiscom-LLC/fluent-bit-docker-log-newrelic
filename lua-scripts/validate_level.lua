function validate_level(tag, timestamp, record)
   level = record["level"]
   modified = 1
   if level ~= nil then
      if level == "INFO" then
         modified = 0
      elseif level == "INF" then
         record["level"] = "INFO"
      elseif level == "ERR" then
         record["level"] = "ERROR"
      elseif level == "WRN" then
         record["level"] = "WARN"
      elseif level == "DBG" then
         record["level"] = "DEBUG"
      else
         record["level"] = "INFO"
      end
   end
   return modified, timestamp, record
end
-- https://github.com/fluent/fluent-bit/discussions/5735
-- https://stackoverflow.com/questions/63554693/fluent-bit-filter-to-convert-unix-epoch-timestamp-to-human-readable-time-format
-- https://stackoverflow.com/questions/63728745/is-it-possible-to-use-a-fluent-bit-records-timestamp
-- https://stackoverflow.com/questions/73000422/how-to-classify-docker-container-logs-by-container-name-using-fluent-bit

