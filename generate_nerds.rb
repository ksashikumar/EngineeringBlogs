#!/usr/bin/env ruby

require 'builder'
require 'feedbag'
require 'json'
require 'net/http'
require 'nokogiri'
require 'uri'

OUTPUT_FILENAME = 'nerds.xml'

readme = File.open('README.md', 'r')
contents = readme.read
matches = contents.scan(/\* (.*) (http.*)/)
unavailable = []

Struct.new('Blog', :name, :web_url, :rss_url)
blogs = []

matches.each_with_index do |match, index|
  name = match[0]
  web_url = match[1]

  rss_url = nil
  if File.exist?(OUTPUT_FILENAME)
    xml = Nokogiri::XML(File.open(OUTPUT_FILENAME))
    existing_blog = xml.xpath("//rssUrl")[index]
    if existing_blog
      rss_url = existing_blog.text
      puts "#{name}: ALREADY HAVE"
    end
  end

  if rss_url.nil?
    puts "#{name}: GETTING"
    rss_check_url = "http://ajax.googleapis.com/ajax/services/feed/lookup?v=1.0&q=#{web_url}"
    uri = URI.parse(rss_check_url)
    response = JSON.parse(Net::HTTP.get(uri))
    rss_url = response['responseData']['url'] if response['responseData'] && response['responseData'].has_key?('url')

    if rss_url.nil?
      rss_url = Feedbag.find(web_url).first
      if rss_url.nil?
        suggested_paths = ['/rss', '/feed', '/feeds', '/atom.xml', '/feed.xml', '/rss.xml', '.atom']
        suggested_paths.each do |suggested_path|
          rss_url = Feedbag.find("#{web_url.chomp('/')}#{suggested_path}").first
          break if rss_url
        end
      end
    end
  end

  if rss_url && rss_url.length > 0
    blogs.push(Struct::Blog.new(name, web_url, rss_url))
  else
    unavailable.push(Struct::Blog.new(name, web_url, rss_url))
  end

end

blogs.sort_by { |b| b.name.capitalize }
unavailable.sort_by { |b| b.name.capitalize }

xml = Builder::XmlMarkup.new(indent: 2)
xml.instruct! :xml, version: '1.0', encoding: 'UTF-8'
xml.tag!('root') do
  blogs.each do |blog|
    xml.tag!('blog') do
      xml.name blog.name
      xml.rssUrl blog.rss_url  
      xml.htmlUrl blog.web_url 
    end
  end
end

output = File.new(OUTPUT_FILENAME, 'wb')
output.write(xml.target!)
output.close

puts "DONE: #{blogs.count} written to #{OUTPUT_FILENAME}"

puts "\nUnable to find an RSS feed for the following blogs:"
puts "==================================================="
unavailable.each do |b|
  puts "#{b.name} | #{b.web_url}"
end
puts "==================================================="
