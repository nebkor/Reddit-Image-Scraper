require 'rubygems'
require 'restclient'
require 'xmlsimple'

iregex = /http:\/\/(i\.){0,1}(minus|imgur).com\/([0-9a-zA-Z]){3,}(\.jpg|\.gif|\.png){0,1}/i
newfiles = Hash.new 0


ARGV.each do |subreddit|
  destination = subreddit

  # get the rss feed
  begin
    data = RestClient.get "http://www.reddit.com/r/#{subreddit}/.rss"
    if data.code != 200
      puts "Invalid subreddit (url)"
      next
    end
  rescue
    puts "Couldn't get #{subreddit}/.rss"
    next
  end
  # get xml from the data
  begin
    xml = XmlSimple.xml_in(data)
  rescue
    puts "XML for subreddit #{subreddit} was invalid."
    exit
  end

  # make the empty directory pics
  begin
    FileUtils.mkdir destination
  rescue
  end

  # get all the links
  links = xml["channel"][0]["item"].collect { |i|
    iregex.match(i["description"][0])
  }

  puts "Checking #{subreddit}"

  # download all the files
  links.each { |lnk|
    next if lnk.nil?
    l = lnk[0]
    img = (/(jpg|gif|png)$/i).match l
    if !img
      [".jpg", ".gif", ".png"].each { |ending|
        candidate = l.to_s + ending
        i = File.join destination, File.basename(candidate)
        gstr = "#{File.join(destination, File.basename(l.to_s))}*"
        g = Dir.glob gstr
        already_have = g.size > 0
        if already_have
          break
        else
          begin
            RestClient.get(candidate) { |response, request, result|
              next unless response.code.to_s.start_with? "200"
              File.open(i, 'w') { |f| f.write response }
              puts "  Wrote #{i}"
              newfiles[subreddit] = newfiles[subreddit] + 1
              break
            }
          rescue
            next
          end
        end
      }
    else
      i = File.join destination, File.basename(l)
      already_have = File.exists? i
      if already_have
        next
      else
        begin
          File.open(i, 'w') { |f| f.write(RestClient.get(l)) }
          puts "  Wrote #{i}"
          newfiles[subreddit] = newfiles[subreddit] + 1
        rescue
        end
      end
    end
  }
end

puts ""
total = 0
newfiles.keys.sort.each do |k|
  num = newfiles[k]
  total = total + num
  puts "#{k}: #{num}" if num > 0
end

puts "\nWrote #{total} new files."
