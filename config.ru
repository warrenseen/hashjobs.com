require 'sinatra'

disable :run
#set :environment, ENV['RACK_ENV'] || :development

 #log = File.new("./log/sinatra.log", "a")
 #error_log = File.new("./log/error.log", "a")
 #STDOUT.reopen(log)
 #STDERR.reopen(error_log)

require 'hashjobs'
run Sinatra::Application
