#!/usr/bin/env ruby

require 'csv'
require 'erb'
require 'mail'
require 'optparse'

Mail.defaults do
  delivery_method :smtp, {
    :address => 'smtp.gmail.com',
    :port => 587,
    :user_name => ENV['GMAIL_SMTP_USER'],
    :password => ENV['GMAIL_SMTP_PASSWORD'],
    :authentication => :plain,
    :enable_starttls_auto => true
  }
end

def generate_picks(csv)
  senders = csv.map {|a| a}
  recievers = csv.map {|a| a}.shuffle
  picks = []
  senders.each do |sender|
    until sender != recievers.last do
      raise "Someone sending to themselves" if recievers.length == 1
      recievers = recievers.shuffle
    end
    sender_hash = sender.to_hash
    sender_hash["pick"] = recievers.pop
    picks.push(sender_hash)
  end
  return picks
end

options = {}
options[:dry] = false

optparse = OptionParser.new do |opts|
  opts.banner = "Asset-tracker database updater"
  opts.separator "Usage: asset-tracker -d DATABASE [OPTIONS]"

  opts.on("-d", "--dryrun", "Flag to display picks to stdout.  Does not send emails.") do |dry|
    options[:dry] = dry
  end

  opts.on("-c", "--csv CSV", "Path to csv file") do |csv|
    options[:csv] = csv
  end

  opts.on("-e", "--erb ERB", "Path to erb file") do |erb|
    options[:erb] = erb
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end

optparse.parse!

if !options[:csv] || !options[:erb]
  raise "Please specify csv and erb"
end

file = options[:csv]
csv = CSV.read(file, { :headers => true })

erb_file = File.open(options[:erb])
erb = ERB.new(erb_file.read)

begin
  picks = generate_picks(csv)
rescue
  retry
end

if options[:dry]
  picks.each do |sender|
    @Name = sender["Name"]
    @pick = sender["pick"]
    puts erb.result
  end
else
  picks.each do |sender|
    @Name = sender["Name"]
    @pick = sender["pick"]
    Mail.deliver do
      from     'rs.yabuta@gmail.com'
      to       sender["Email"]
      subject  "RCI Steam Secret Santa Pick"
      body     erb.result
    end
  end
end 
