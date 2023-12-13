require 'fileutils'
require 'json'

DEPLOYER_HOME = '/home/deployer'.freeze
DIFF_LHS_TAG = '<'.freeze
DIFF_RHS_TAG = '>'.freeze

COMPARISON_LOG_BASE_DIR = "#{DEPLOYER_HOME}/scripts/logs".freeze
COMPARISON_LOG_SUFFIX = '-mqp-json-comparator.log'.freeze

ORM_LOG_JSON_TAG = 'JSON|'.freeze
ORM_LOG_NAME_DATE_REGEX = /^(?<router_name>\w+)-order-router-monitor_(?<date>\d{8})_0\.log$/.freeze
ORM_LOG_FILE_PATH = File.join(DEPLOYER_HOME, 'logs').freeze

MQP_FILE_REGEX = /^(?<router>mq_recorder_\w+)-twMQProducer_(?<date>\d{8})_(?<process_id>\d+)_0\.log$/.freeze

def log(router, message)
  puts "#{Time.now} - #{message}"
  File.write(File.join(COMPARISON_LOG_BASE_DIR, "#{router}#{COMPARISON_LOG_SUFFIX}"), "#{Time.now} - #{message}\n", mode: 'a')
end

def orm_file_regex_match(file_name)
  ORM_LOG_NAME_DATE_REGEX.match(file_name)
end

def orm_log_files(router)
  log_files = Dir[File.join(ORM_LOG_FILE_PATH, "#{router}*")].sort_by { |f| File.mtime(f) }
  log(router, "orm log files: #{log_files}")

  log_files.map { |file| File.basename(file) }
end

# need to match on date and router since all logs are in same dir
def orm_file_matches_date?(file_name, date)
  match = orm_file_regex_match(file_name)
  return false unless match

  match[:date].eql? date
end

def mqp_path_by_router(router)
  File.join(DEPLOYER_HOME, router, 'mq-producer', 'logs')
end

def mq_file_regex_match(file_name)
  MQP_FILE_REGEX.match(file_name)
end

def mqp_file_matches_date?(file_name, date)
  match = mq_file_regex_match(file_name)
  return false unless match

  match[:date].eql? date
end

def mqp_file_date(file_name)
  match = mq_file_regex_match(file_name)
  return nil unless match

  match[:date]
end

def mqp_log_files(router)
  log_files = Dir[File.join(mqp_path_by_router(router), "*mq_recorder_#{router}*.log")].sort_by { |f| File.mtime(f) }
  log(router, "mqp log files: #{log_files}")

  log_files.map { |file| File.basename(file) }
end

def comparison_prefix(router, date)
  "#{router}_#{date}"
end

def combined_mqp_file_name(router, date)
  "#{COMPARISON_LOG_BASE_DIR}/#{comparison_prefix(router, date)}-combined-mqp-logs"
end

def combine_mqp_files(mqp_files, router, date)
  # combine all mqp files into one file
  out_file = File.open(combined_mqp_file_name(router, date), 'w')
  mqp_files.each do |file|
    File.foreach(File.join(mqp_path_by_router(router), file)) do |line|
      out_file.puts(line)
    end
  end
  out_file.close
end

def diff_json_file_name(router, date)
  File.join(COMPARISON_LOG_BASE_DIR, "#{comparison_prefix(router, date)}-diff-json")
end

def mqp_json_file_name(router, date)
  File.join(COMPARISON_LOG_BASE_DIR, "#{comparison_prefix(router, date)}-mqp-json")
end

def orm_json_file_name(router, date)
  File.join(COMPARISON_LOG_BASE_DIR, "#{comparison_prefix(router, date)}-orm-json")
end


## Script Begin ##
if ARGV.length < 1
  puts 'Usage: mqp_json_comparison.rb <router_name>'
  exit
end
router_name = ARGV[0]

# Create the output directory if it doesn't exist
FileUtils.mkdir_p(COMPARISON_LOG_BASE_DIR) unless Dir.exist?(COMPARISON_LOG_BASE_DIR)

# Grab the trade date from the latest mqp log file
dates = mqp_log_files(router_name).map { |file| mqp_file_date(file) }
log(router_name, "Dates found for mqp files: #{dates}")
date = dates.compact.last
log(router_name, "Selecting date: #{date} for comparison")

# Now grab all mqp and orm files that match on the date and router name
mqp_files = mqp_log_files(router_name).select { |file| mqp_file_matches_date?(file, date) }
orm_files = orm_log_files(router_name).select { |file| orm_file_matches_date?(file, date) }
exit if mqp_files.empty? || orm_files.empty?

# grab the latest orm file. This script assumes there will only be one file that matches the date and router name
orm_file = orm_files.last
if orm_file.nil?
  log(router_name, "No orm file found for #{date}, exiting")
  exit
end

# Lump all the MQP files into one file so we can just walk it (in case of restarts)
combine_mqp_files(mqp_files, router_name, date)

# get all the mqp lines, and all the orm lines that contain JSON
mqp_lines = IO.readlines(combined_mqp_file_name(router_name, date))
orm_lines = IO.readlines(File.join(ORM_LOG_FILE_PATH, orm_file)).select { |line| line.include? ORM_LOG_JSON_TAG }

# log some stats
log(router_name, "mqp lines read from #{combined_mqp_file_name(router_name, date)}: #{mqp_lines.count}")
log(router_name, "orm lines read from #{File.join(ORM_LOG_FILE_PATH, orm_file)}: #{orm_lines.count}")

# Extract the JSON payload from each log file
mqp_lines.each do |line|
  File.write(mqp_json_file_name(router_name, date), line.partition('"payload":"')[2].partition('","routing_key')[0].gsub('\\', '') + "\n")
end
orm_lines.each do |line|
  File.write(orm_json_file_name(router_name, date), line.partition('JSON|')[2] + "\n")
end

# Run linux Diff
result = system("diff #{mqp_json_file_name(router_name, date)} #{orm_json_file_name(router_name, date)} > #{diff_json_file_name(router_name, date)}")
log(router, 'JSON is equal, exiting') if result

# iterate over file1's json and build an array of json objects
mqp_file_json = []
File.read(diff_json_file_name(router_name, date)).each_line do |line|
  next unless line.include?(DIFF_LHS_TAG)
  text_to_parse = line.partition(DIFF_LHS_TAG)[2].strip
  next if text_to_parse.empty?

  json = JSON.parse(line.partition(DIFF_LHS_TAG)[2].strip)
  mqp_file_json << json if json
end

# iterate over file2's json and build an array of json objects
orm_file_json = []
File.read(diff_json_file_name(router_name, date)).each_line do |line|
  next unless line.include?(DIFF_RHS_TAG)
  text_to_parse = line.partition(DIFF_RHS_TAG)[2].strip
  next if text_to_parse.empty?

  json = JSON.parse(line.partition(DIFF_RHS_TAG)[2].strip)
  orm_file_json << json if json
end

# compare file1 and file2 json objects
mqp_file_json.each_with_index do |json, index|
  log(router_name, "JSON Message Index #{index}---------------------")
  json.map do |k, v|
    if v != orm_file_json[index][k]
      log(router_name, "  #{k} is not equal")
      log(router_name, "      #{mqp_json_file_name(router_name, date)}: #{v}")
      log(router_name, "      #{orm_json_file_name(router_name, date)}: #{orm_file_json[index][k]}")
    end
  end
  log(router_name, "------------------------------------------------")
end

# output the diff as ROUTER_NAME-diff