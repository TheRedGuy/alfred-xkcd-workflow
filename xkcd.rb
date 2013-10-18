require 'open-uri'

# Limit the number of comics allowed to preview in a single run
# Feel free to change this value
LIMIT_COMICS = 5

def parse_comic(url)
  json = open(url).read
  {
    :number => json.match(/"num": \d+/)[0].split(":").last.strip.to_i,
    :title  => json.match(/"title": "[^"]+/)[0].split(":").last.strip[1..-1],
    :link   => json.match(/http:[^"]+/)[0].gsub("\\/","/")
  }
end

def show_comic(hash)
  number, title, link = hash[:number], hash[:title], hash[:link]
  return unless number && title && link

  name  = Regexp.escape("#{title} (##{number}).png")
  image = "/tmp/#{name}"

  system "curl -s '#{link}' >> #{image}"
  system "qlmanage -p #{image} $1>/dev/null"
  system "rm #{image}"
end

# Get the latest comic info, to use for reference, or display
latest_comic = parse_comic 'http://xkcd.com/info.0.json'

# Check the first argument; discard the rest
arg = ARGV.first ? ARGV.first.strip.split(' ').first : ""

comic_numbers = case arg
when /^\d+$/
  # Fetch the n-th last comic
  # ex: 1st == last; 2nd == last - 1
  [ latest_comic[:number] - arg.to_i ]

when /^\#\d+$/
  # Fetch comic with specific number
  [ arg[1..-1].to_i ]

when /^\.\.\.?\d+$/
  # Fetch a rage of last comics
  # ex: ...5 == last 5 comics
  n = arg.scan(/\d+/).first.to_i
  n.times.map{|offset| latest_comic[:number] - offset }

when /^\#\d+\.\.\.?\#?\d+$/
  # Fetch specific range of comics
  # NOTE: the numbers are pre-sorted!
  pair  = arg.scan(/\d+/).map(&:to_i).sort
  Range.new(*pair).to_a

else
  # Just show it, no other fetch required
  show_comic latest_comic
  []
end

# Respect the limit
exit if comic_numbers.size > LIMIT_COMICS

comic_numbers.each do |n|
  # Check if number is in range 1...latest
  next if n > latest_comic[:number] || n < 1
  show_comic parse_comic("http://xkcd.com/#{n}/info.0.json")
end
