DIFF_LHS_TAG = '<'.freeze
DIFF_RHS_TAG = '>'.freeze

COMPARISON_BASE_DIR = '/home/deployer/scripts/logs'.freeze
COMPARISON_OUTPUT_LOG = "#{COMPARISON_BASE_DIR}/mqp-json-comparator.log".freeze

ORM_LOG_JSON_TAG = 'JSON|'.freeze
ORM_LOG_NAME_DATE_REGEX = /^(?<router_name>\w+)_order-router-monitor_(?<trade_date>\d{8})_0\.log$/.freeze
ORM_LOG_FILE_PATH = '/home/deployer/logs'.freeze

MQP_FILE_REGEX = /mq_recorder\w+\d+_(?<date>[0-9]{8})\S*\.{1}log$/.freeze

def orm_file_regex_match(file_name)
  ORM_LOG_NAME_DATE_REGEX.match(file_name)
end

def orm_log_files
  Dir[ORM_LOG_FILE_PATH].sort_by { |f| File.mtime(f) }
end

# need to match on date and router since all logs are in same dir
def orm_file_matches_date_and_router?(file_name, date, router)
  match = orm_file_regex_match(file_name)
  return false unless match

  Date.parse(match[:date]).eql? date && match[:router_name].eql?(router)
end

def mq_file_regex_match(file_name)
  MQP_FILE_REGEX.match(file_name)
end

def mqp_file_matches_name_and_date?(file_name, date)
  match = mq_file_regex_match(file_name)
  return false unless match

  Date.parse(match[:date]).eql? date
end

def mqp_file_date(file_name)
  match = mq_file_regex_match(file_name)
  return nil unless match

  Date.parse(match[:date])
end

def mqp_log_files(router)
  Dir["home/deployer/#{router}/mq-producer/logs"].sort_by { |f| File.mtime(f) }
end

def comparison_prefix(router, date)
  "#{router}_#{date}"
end
def combined_mqp_file_name(router, date)
  "#{COMPARISON_BASE_DIR}/#{comparison_prefix(router, date)}-combined-mqp-logs"
end

def combine_mqp_files(mqp_files, router, date)
  # combine all mqp files into one file
  out_file = File.open(combined_mqp_file_name(router, date), 'w')
  mqp_files.each do |file|
    File.foreach(file) do |line|
      out_file.puts(line)
    end
  end
end

def diff_json_file_name(router, date)
  "#{COMPARISON_BASE_DIR}/#{comparison_prefix(router, date)}-diff-json"
end

def mqp_json_file_name(router, date)
  "#{COMPARISON_BASE_DIR}/#{comparison_prefix(router, date)}-mqp-json"
end

def orm_json_file_name(router, date)
  "#{COMPARISON_BASE_DIR}/#{comparison_prefix(router, date)}-orm-json"
end

## Script Begin
if ARGV.length < 1
  puts 'Usage: mqp-json-comparison.rb <router_name>'
  exit
end
router_name = ARGV[0]

# Grab the trade date from the latest mqp log file
dates = mqp_log_files(router_name).map { |file| mqp_file_date(file) }
date = date.compact.last

# Now grab all mqp and orm files that match on the date and router name
mqp_files = mqp_log_files.select { |file| mqp_file_matches_name_and_date?(file, date) }
orm_files = orm_log_files.select { |file| orm_file_matches_date_and_router?(file, date, router_name) }
exit if mqp_files.empty? || orm_files.empty?

# grab the latest orm file. This script assumes there will only be one file that matches the date and router name
orm_file = orm_files.last
if orm_file.nil?
  File.write(COMPARISON_OUTPUT_LOG, "No orm file found for #{router_name} on #{date}, exiting")
  exit
end

# Lump all the MQP files into one file so we can just walk it (in case of restarts)
combine_mqp_files(mqp_files, router_name, date)

# get all the mqp lines, and all the orm lines that contain JSON
mqp_lines = IO.readlines(combined_mqp_file_name(router_name, date))
orm_lines = IO.readlines(orm_file).select { |line| line.include? ORM_LOG_JSON_TAG }

# Extract the JSON payload from each log file
mqp_lines.each do |line|
  File.write(mqp_json_file_name(router_name, date), line.partition('"payload":"')[2].partition('","routing_key')[0].gsub('\\', '') + "\n")
end
orm_lines.each do |line|
  File.write(orm_json_file_name(router_name, date), line.partition('JSON|')[2] + "\n")
end

# Run linux Diff
system("diff #{mqp_json_file_name(router_name, date)} #{orm_json_file_name(router_name, date)} > #{diff_json_file_name(router_name, date)}")

# iterate over file1's json and build an array of json objects
mqp_file_json = []
File.read(diff_json_file_name(router_name, date)).each_line do |line|
  next unless line.include?(DIFF_LHS_TAG)
  json = JSON.parse(line.partition(DIFF_LHS_TAG)[2].strip)
  mqp_file_json << json
end

# iterate over file2's json and build an array of json objects
orm_file_json = []
File.read(diff_json_file_name(router_name, date)).each_line do |line|
  next unless line.include?(DIFF_RHS_TAG)
  json = JSON.parse(line.partition(DIFF_RHS_TAG)[2].strip)
  orm_file_json << json
end

# compare file1 and file2 json objects
mqp_file_json.each_with_index do |json, index|
  puts "JSON Message Index #{index}---------------------"
  json.map do |k, v|
    if v != orm_file_json[index][k]
      puts "#{k} is not equal"
      puts "    #{mqp_json_file_name(router_name, date)}: #{v}"
      puts "    #{orm_json_file_name(router_name, date)}: #{orm_file_json[index][k]}"
    end
  end
  puts "------------------------------------------------"
end

# output the diff as ROUTER_NAME-diff