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
			raise Gist::Error, 'github.token is not set' if token.empty?
			return {'login' => user, 'token' => token}
		end

		def Push.url
			return URI.parse('http://gist.github.com/gists')
		end

		attr_reader :url

		def initialize(private = false, anonymous = false)
			@contents = Array.new
			@private = private
			@anonymous = anonymous
		end

		def add(data, path = nil)
			@contents.push([data, path])
		end

		def form
			raise Gist::Error, 'No input files are specified' if @contents.empty?
			h = Hash.new
			@contents.each_with_index do |content, idx|
				data, path = content
				h["file_ext[gistfile#{idx+1}]"] = nil
				h["file_name[gistfile#{idx+1}]"] = File.basename(path)
				h["file_contents[gistfile#{idx+1}]"] = data
			end
			h['private'] = 'on' if @private
			h.merge!(Push.auth) unless @anonymous
			return h
		end

		def post!
			res = Net::HTTP::Proxy(Gist.proxy).post_form(Push.url, form)
			case res
			when Net::HTTPFound
				@url = res['location']
				return self
			else
				raise Gist::Error, "#{res.code} #{res.message}"
			end
			return nil
		end
	end
end

if __FILE__ == $0
	require 'optparse'
	opt = OptionParser.new
	opt.banner = "Usage: #{File.basename($0)} [options] [file(s)]\nPosts stdin or file(s) to gist.github.com"

	is_anon = false
	is_priv = false
	is_dry = false
	opt.on('-a', '--anonymous', 'Posts gist as anonymous'){is_anon = true}
	opt.on('-p', '--private', 'Makes gist private'){is_priv = true}
	opt.on('-n', '--dryrun', 'Does not post. Prints data to be sent.'){is_dry = true}
	opt.on('-h', '--help', 'Prints this message and quit'){
		puts opt.help
		exit 0
	}
	begin
		opt.parse!
	rescue OptionParser::InvalidOption
		$stderr.puts $!
		$stderr.puts opt.help
		exit 1
	end

	begin
		gist = Gist::Push.new(is_priv, is_anon)
		ARGV.each do |src|
			File.open(src) do |f|
				gist.add(f.read, src)
			end
		end
		unless is_dry
			gist.post!
			puts gist.url
		else
			require 'pp'
			pp gist.form
		end
	rescue Gist::Error
		$stderr.puts $!
		exit 1
	end
end
