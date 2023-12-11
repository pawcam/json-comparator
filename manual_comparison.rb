# MANUAL COMPARISON
orm_lines = IO.readlines('orm').select { |line| line.include? 'JSON|' }
mqp_lines = IO.readlines('mqp')

# Extract the JSON payload from each sx log file
mqp_lines.each do |line|
  File.write('mqp-json', line.partition('"payload":"')[2].partition('","routing_key')[0].gsub('\\', '') + "\n")
end
orm_lines.each do |line|
  File.write('orm-json', line.partition('JSON|')[2] + "\n")
end

# Run linux Diff
file1 = 'mqp-json'
file2 = 'orm-json'
system("diff #{file1} #{file2} > diff_json")

# iterate over file1's json and build an array of json objects
mqp_file_json = []
File.read('diff_json').each_line do |line|
  next unless line.include?('<')
  json = JSON.parse(line.partition('<')[2].strip)
  mqp_file_json << json
end

# iterate over file2's json and build an array of json objects
file_2_json = []
File.read('diff_json').each_line do |line|
  next unless line.include?('>')
  json = JSON.parse(line.partition('>')[2].strip)
  file_2_json << json
end

# compare file1 and file2 json objects
mqp_file_json.each_with_index do |json, index|
  json.map do |k, v|
    if v != file_2_json[index][k]
      puts "#{k} is not equal"
      puts "    #{file1}: #{v}"
      puts "    #{file2}: #{file_2_json[index][k]}"
    end
  end
  puts "---------------------"
end