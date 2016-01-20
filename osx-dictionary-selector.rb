$: << File.dirname(__FILE__)
$: << File.join(File.dirname(__FILE__), "lib")

require 'alfred_feedback'
include AlfredFeedback

require 'cfpropertylist'
require 'pp'

global_dict_dir = '/Library/Dictionaries'
local_dict_dir = File.expand_path('~/Library/Dictionaries')

def get_dictionaries(dir)
  result = []
  Dir::glob(dir + "/*/Contents/Info.plist").each do |file|
    data = []
    plist = CFPropertyList::List.new(:file => file)
    plist.value.value.each do |h|
      if h[0] == "CFBundleIdentifier"
        data[0] = h[1].value
      elsif h[0] == "CFBundleDisplayName"
        data[1] = h[1].value
      elsif h[0] == "CFBundleName"
        data[2] = h[1].value
      end
    end
    result << data
  end
  return result
end

# begin
  feedback = Feedback.new
  path = Feedback.get_path
  query = Feedback.get_query

  if path == :root
    dictionaries = []
    dictionaries.concat(get_dictionaries(global_dict_dir))
    dictionaries.concat(get_dictionaries(local_dict_dir))
    dictionaries.each do |identifier, name, category|
      next unless identifier
      arg = query.gsub(" "){"\\ "} + ":" + identifier
      name = name.to_s
      category = category.to_s
      if name.index category
        display = name
      elsif name == ""
        display = category
      elsif category == ""
        display = name
      else
        display = "#{name} (#{category})"
      end
      feedback.add_item(display, :arg => arg, :icon => "icon.png")
    end
  end
  
  puts feedback.to_xml
# rescue => e
# end

