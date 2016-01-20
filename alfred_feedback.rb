#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'yaml'

module AlfredFeedback
	@@SEPARATOR = "→"
	@@timestamp = Time.now.to_i

	class Item
		attr_accessor :uid, :arg, :title, :subtitle, :icon, :valid, :autocomplete, :icontype
		
		def initialize(title, opts = {})
			@title    = title || ""

			@uid      = opts[:uid] || title
			@arg      = opts[:arg] || title
			@subtitle = opts[:subtitle] || ""
			@icon     = opts[:icon] || "icon.png"
			@valid    = opts[:valid]
			@valid    = true if @valid.nil?
			@autocomplete = opts[:autocomplete] || nil
		end

		def autocomplete_to str
			@autocomplete = str
		end

		def autocomplete_to_title title
			autocomplete_to path + title
		end

		def autocomplete_to_sub sub
			autocomplete_to_title sub + " " + @@SEPARATOR + " "
		end

		def path
			path = Feedback.get_path
			return "" if path == :root
			return path.join(" #{@@SEPARATOR} ") + " #{@@SEPARATOR} "
		end

		def to_xml
			o = "  <item uid=\"#@uid\" arg=\"#@arg\""
			o+= " valid=\"no\"" if !@valid
			o+= " autocomplete=\"#{@autocomplete}\"" if !@autocomplete.nil?
			o+= ">\n"
			o+= "    <title>#{@title}</title>\n"
			o+= "    <subtitle>#{@subtitle}</subtitle>\n"
			o+= "    <icon"
			o+= " type=\"#{@icontype}\"" if !@icontype.nil?
			o+= ">#{@icon}</icon>\n"
			o+= "    <valid>no</valid>\n" if !@valid
			o+= "  </item>\n"
			
			o
		end
	end

	class Menu < Item
		def initialize(title, opts = {})
			opts[:valid] = false
			
			super
			autocomplete_to_sub(@arg || "")
		end
	end

	class BackItem < Menu
		def initialize label='Back…'
			super(label, :arg => "", :icon => 'back.png')
			autocomplete_to "" if Feedback.get_path.length == 1
		end

		def path
			path = Feedback.get_path
			path.pop
			path = path.join(" #{@@SEPARATOR} ")
		end
	end

	class Feedback
    attr_accessor :items
		def initialize
			@items = []
			@fixed_order = false
			@autofilter = false
			@filter_subtitle = false
		end

		def build_completion
			# find common substring
			strs = []
			@items.each { |item|
				strs << item.title
			}

			common = strs.inject { |m, s| s[0,(0..m.length).find { |i| m.downcase[i] != s.downcase[i] }.to_i] }
			return if common.nil? || common.empty?

			@items.each { |item|
				next unless item.autocomplete.nil?
				item.autocomplete_to_title common
			}
		end

		def fixed_order fixed=true
			@fixed_order = fixed
		end

		def add_back_item(label='Back…')
			return if Feedback.get_path == :root
			@items << BackItem.new(label)
		end
		
		def add_item(title, opts = {})
			opts[:uid] ||= @@timestamp + @items.length if @fixed_order
			item = Item.new(title, opts)
			@items << item
			return item
		end

		def add_menu(title, opts = {})
			opts[:uid] ||= @@timestamp + @items.length if @fixed_order
			menu = Menu.new(title, opts)
			@items << menu
			return menu
		end

		def get_item(title)
			@items.find { |i| i.title == title }
		end

		def filter_results
			q = Feedback.get_query.downcase
			q = q.split(" ")
			q.each { |s|
				pattern = Regexp.new(s)
				@items.delete_if { |i|
					a = i.title.downcase.index(pattern).nil?
					a = a && i.subtitle.downcase.index(pattern).nil? if @filter_subtitle
					a
				}
			}
		end

		def to_xml
			filter_results   if @autofilter
      # build_completion
      query = Feedback.get_query
      add_item("No results", :subtitle => 'for "' + query + '"', :valid => false) if @items.empty? && query.size > 1
      # if @items.size > $MAX_ITEM_SIZE
      #   @items = []
      #   add_item("Too many results", :subtitle => 'for "' + Feedback.get_query + '"', :valid => false) 
      # end

			xml =  "<?xml version=\"1.0\" ?>\n"
			xml += "<items>\n"
			xml += @items.map(&:to_xml).join("\n")
			xml += "</items>"

			xml
		end

		def self.get_path
			path = ARGV.join(" ") + " "
			path = path.split(@@SEPARATOR).map!(&:strip)
			return :root if path.length < 2
			return path[0, path.length-1]
		end

		def self.get_query
			path = ARGV.join(" ") + " "
			path = path.split(@@SEPARATOR).map(&:strip).last
			path
		end

		def autofilter
			@autofilter = true
		end

		def filter_with_subtitle
			@filter_subtitle = true
		end

		def self.separator= sep
			@@SEPARATOR = sep
		end

		def self.bundle_id
			begin
				return File.read("info.plist").match(/<key>bundleid<\/key>\s*<string>(.*)<\/string>/)[1]
			rescue
				return ""
			end
		end
	end

	def self.cache_directory
		File.expand_path "~/Library/Caches/com.runningwithcrayons.Alfred-2/Workflow Data/#{Feedback.bundle_id}/"
	end

	def self.get_cache
		begin
      return YAML.load_file("#{cache_directory}/cache")
		rescue
			return Hash.new
		end
	end

	def self.save_cache cache
		return false if cache.nil?
    begin
  		`mkdir -p "#{cache_directory}"` unless File.exists? cache_directory
	  	File.open("#{cache_directory}/cache", "w"){ |f| f.write cache.to_yaml }
    rescue
      return false
    end
    return true
	end


	def self.data_directory
		File.expand_path "~/Library/Application Support/Alfred 2/Workflow Data/#{Feedback.bundle_id}/"
	end

	def self.get_config
		begin
			return YAML.load_file("#{data_directory}/config")
		rescue
			return Hash.new
		end
	end

	def self.save_config config
		return if config.nil?
		`mkdir -p "#{data_directory}"`
		File.open("#{data_directory}/config", "w"){ |f| f.write config.to_yaml }
	end

end

