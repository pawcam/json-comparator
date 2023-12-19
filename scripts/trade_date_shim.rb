#!/usr/bin/env ruby

require 'market_time'
require 'optparse'

def get_trade_date(service_instrument_type)
  if [MarketTime::InstrumentCollections::CITADEL_CRYPTOCURRENCY,
      MarketTime::InstrumentCollections::DV_CHAIN,
      MarketTime::InstrumentCollections::JANE_STREET].include?(service_instrument_type)
    return MarketTime.cryptocurrencies_trade_date(instrument_collection: service_instrument_type).strftime('%Y%m%d')
  end

  MarketTime.futures_trade_date(instrument_collection: service_instrument_type).strftime('%Y%m%d')
end

router_name = ""
OptionParser.new do |opts|
  opts.banner = 'Usage: action service_name'

  router_name = opts.default_argv[0]
  fail 'router name must not be nil' if router_name.nil?
  puts router_name
end.parse!

if router_name.include?('CBOE_DIGITAL')
  service_instrument_type = MarketTime::InstrumentCollections::CBOE_DIGITAL_FUTURES
elsif router_name.include?('CFE')
  service_instrument_type = MarketTime::InstrumentCollections::CFE
elsif router_name.include?('CITADEL_CRYPTOCURRENCY')
  service_instrument_type = MarketTime::InstrumentCollections::CITADEL_CRYPTOCURRENCY
elsif router_name.include?('CME')
  service_instrument_type = MarketTime::InstrumentCollections::CME
elsif router_name.include?('DV_CHAIN')
  service_instrument_type = MarketTime::InstrumentCollections::DV_CHAIN
elsif router_name.include?('JANE_STREET')
  service_instrument_type = MarketTime::InstrumentCollections::JANE_STREET
else
  puts 'This should only be used with valid crypto and futures venues. Exiting.'
  exit
end

puts get_trade_date(service_instrument_type)
