require 'twitter'
require 'activesupport'
require 'action_view'
require 'classifier'
require 'madeleine'
require 'sinatra'
require 'yaml'

helpers do
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::TagHelper
  
	def twitter_url_for(user, id=nil)
	  if id.nil?
		  "http://twitter.com/#{user}"
	  else
  	  "http://twitter.com/#{user}/status/#{id}"
    end
	end
	
	def link_to(name, url=nil, html_options={})
	  url = name if url.nil?
	  "<a href=\"#{url}\" #{tag_options(html_options)}>#{name}</a>"
  end
  
  def span(text, html_options={})
    "<span #{tag_options(html_options)}>#{text}</span>"
  end
  
  def twitter_link_to(user)
    link_to("@#{user}", twitter_url_for(user), :target => "_blank", :class => "external")
  end
	
	def format_text(text)
	  # hilite @names
	  # hilite #tags
	  # linkify urls
	  text.
	  gsub(/((ftp|http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?)/i) {|m| link_to $1, $1, :target => "_blank", :class => "external" }.
	  gsub(/@(\w+)/) {|m| link_to($&, twitter_url_for($1), :target => "_blank", :class => "name") }.
	  gsub(/(\A|\s)(#\w+)/, '\1<span class="tag">\2</span>')
	  
  end
  
  def render_pagination(page, is_first, is_last)
    link_or_span(page-1, is_first, '&laquo; Previous', :class => "prev_page") +
    link_or_span(page+1, is_last, 'Next &raquo;', :class => "next_page")
  end
  
  def link_or_span(page, disabled, text, html_options ={})
    if disabled
     html_options[:class] += " disabled"
     span text, html_options
    else
      link_to text, "/p/#{page}", html_options
    end
  end
  
  def is_iphone(request)
    request.user_agent.include?('iPhone')
  end
end

get '/css/:name.css' do
  header 'Content-Type' => 'text/css; charset=utf-8'
  css :name	
end

get '/about' do
  erb :about
end

get %r{/p/(\d+)} do
  @page = params[:captures].first.to_i
  #STDERR.puts "Last updated: #{$last_updated}"
  
  if $last_updated + UpdateInterval < Time.now || Cache[@page].nil?
  	$last_updated = Time.now
  	result = nil
  	loop do
	    result = Search.page(@page).fetch
	    break unless result.nil? || result.results.nil?
	    sleep(2)
    end
    #STDERR.puts "Cache refresh for page #{@page} at #{Time.now}"
    Cache[@page] = result unless result.nil?
  end
  
  last_modified($last_updated)
  
  unless Cache[@page].nil?
    #STDERR.puts "Cache hit for page #{@page} at #{Time.now}"
    @results = Cache[@page].results
    @is_first_page = (@page == 1)
    @is_last_page = Cache[@page].next_page.nil?
  else
    #STDERR.puts "Cache miss for page #{@page} at #{Time.now}"
  	# invalidate last_updated time
  	$last_updated = Time.now - UpdateInterval
  	@results = {}
  	@is_first_page = (@page == 1)
  	@is_last_page = true
  end
  erb :index
end

get '/' do
  redirect '/p/1'
end

configure do
  Config = YAML.load_file("config.yaml")
  
  Cache = []
  UpdateInterval = Config['update_interval']
  Search = Twitter::Search.new(Config['terms'].join(' OR ')).lang(Config['lang']).per_page(Config['per_page'])
  Maddy = SnapshotMadeleine.new("bayes_data") do
    Classifier::Bayes.new 'HAJ','NAJ','Noise'
  end
  $last_updated = Time.now - UpdateInterval # ensure the first request is outdated.
end
  