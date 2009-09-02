#!/usr/bin/env ruby
# gist-cat.rb - a small command line tool to handle data to/from gist
#
# Copyright (c) 2009 zunda
#
# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#
require 'net/http'
Net::HTTP.version_1_2
require 'uri'

class Gist
	class Error < Exception; end

	def Gist.proxy
		(proxy = ENV['http_proxy']) ? URI.parse(proxy) : nil
	end

	class Push
		def Push.auth
			user  = `git config github.user`.strip
			raise Gist::Error, 'github.user is not set' if user.empty?
			token = `git config github.token`.strip
			raise Gist::Error, 'github.token is not set' if user.empty?
			return {'login' => user, 'token' => token}
		end

		def Push.url
			return URI.parse('http://gist.github.com/gists')
		end

		attr_reader :url

		def initialize(private = false)
			@contents = Array.new
			@private = private
		end

		def add(data, path = nil)
			@contents.push([data, path])
		end

		def form
			raise 'No input files are specified' if @contents.empty?
			h = Hash.new
			@contents.each_with_index do |content, idx|
				data, path = content
				h["file_ext[gistfile#{idx+1}]"] = nil
				h["file_name[gistfile#{idx+1}]"] = File.basename(path)
				h["file_contents[gistfile#{idx+1}]"] = data
			end
			h['private'] = 'on' if @private
			h.merge(Push.auth)
			return h
		end

		def post
			res = Net::HTTP::Proxy(Gist.proxy).post_form(Push.url, form)
			@url = res['location']
			return self
		end
	end
end

if __FILE__ == $0
	begin
		gist = Gist::Push.new
		ARGV.each do |src|
			File.open(src) do |f|
				gist.add(f.read, src)
			end
		end
		gist.post
		puts gist.url
	rescue Gist::Error
		$stderr.puts "#{$0}: #{$!}"
		exit 1
	end
end
