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
	def Gist.proxy
		(proxy = ENV['http_proxy']) ? URI.parse(proxy) : nil
	end

	class Push
		def Push.auth
			user  = `git config github.user`.strip
			unless user.empty?
				token = `git config github.token`.strip
				return {'login' => user, 'token' => token}
			else
				return {}
			end
		end

		def Push.url
			return URI.parse('http://gist.github.com/gists')
		end

		attr_reader :url

		def initialize(content, filename = nil, private = nil)
			@content = content
			@filename = filename
			@private = private
		end

		def form
			h = {
				'file_ext[gistfile1]'      => nil,
				'file_name[gistfile1]'     => @filename,
				'file_contents[gistfile1]' => @content
			}
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
	gist = Gist::Push.new(File.open(ARGV[0]).read, ARGV[0]).post
	puts gist.url
end
