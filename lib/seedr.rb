require 'uri'
require 'net/http'
require 'net/https'
require 'rexml/document'
require 'rss/2.0'
require 'open-uri'
require 'digest/md5'
require 'iconv'

require 'rubygems'
require 'nokogiri'
require 'activesupport'

$:.unshift(File.dirname(__FILE__))
require 'multipart_post_request'
require 'seedr/ext'
require 'seedr/video'

Dir[File.join(File.dirname(__FILE__), %w{seedr sites *})].each do |f|
  if File.file? f
    require f
  end
end
require 'seedr/bot'

module Seedr
  class CantConnect < StandardError; end
  class AuthError < StandardError; end
end
