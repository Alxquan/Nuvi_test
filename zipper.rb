require 'zip'
require 'pry'
require 'HTTParty'
require 'nokogiri'
require 'redis'


# Read files from url
def read_files
  base_url = HTTParty.get('http://feed.omgili.com/5Rh5AMTrc4Pv/mainstream/posts/')

  # Parse body for href
  parse_page = Nokogiri::HTML(base_url)
  parsed_a = parse_page.css('a').map { |zip| zip['href']
  }

  # Takes all hrefs, checks them for zips
  # Creates an array of those zips
  files = parsed_a.select!{|f|f =~ /.zip/}

  puts "This may take a minute"
  #Loops through array of zip files
  files.each do |x|
    puts "Currently downloading #{x}"
    xml_files = "temp_zip_files/xml/"

    #Makes temporary directory to store extracted XML files
    Dir.mkdir(xml_files) unless File.exists?(xml_files)

    files = []
    files << HTTParty.get("http://feed.omgili.com/5Rh5AMTrc4Pv/mainstream/posts/#{x}")

    #Loops through all files, unzips them and pushes them to Redis under key NEWS_XML
    files.each do |file|
      Zip::File.open_buffer(file.body) do |zip_file|
        r = Redis.new
        zip_file.each do |entry|
          puts "Extracting #{entry.name}"
          entry.extract(xml_files) unless File.exist?(xml_files)
          #Code segment that came with rubyzip gem?
          # content = entry.get_input_stream.read
          r.lrem('NEWS_XML', 1, file)
          r.lpush('NEWS_XML', file)
        end
        puts "Saved entries to Redis"
      end
    end
  end
end

read_files
