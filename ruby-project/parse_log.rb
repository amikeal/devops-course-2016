require 'date'
require 'open-uri'

# Config options
REMOTE_URL = 'http://physis.arch.tamu.edu/files/http_access_log'
LOCAL_FILE = 'http_access_log.bak'
LOG_PATH = 'logs/'

# Initialize some variables
i = 0
requests_by_month = {}
files = {}
counts = {}
errors = []

# Fetch the file from the remote server and save it to disk
print "\n\nDownloading log file from URI... "
download = open(REMOTE_URL)
IO.copy_stream(download, LOCAL_FILE)
puts "File retrieved and saved to disk (#{LOCAL_FILE}) \n\n"

# Loop through each line of the file on disk
File.foreach(LOCAL_FILE) do |line|
	# A simple progress meter
	i += 1
	if i % 1000 == 0 then print "." end

	# Simple split on spaces is good enough here?
	#vals = line.split(" ")

	# Nope. Use Regex
	vals = /.*\[(.*) \-[0-9]{4}\] \"([A-Z]+) (.+?)( HTTP.*\"|\") ([2-5]0[0-9]) .*/.match(line)

	# Sanity check the line -- capture the error and move on
	if !vals then
		errors.push(line)
		next
	end

	# Grab the data from the fields we care about
	req_date = Date.strptime(vals[1], '%d/%b/%Y:%H:%M:%S')
	mon_year = req_date.strftime('%Y-%m')
	http_verb = vals[2]
	file_name = vals[3]
	stat_code = vals[5]

	# Add the file name to the hash if not there; increment otherwise
	files[file_name] = (if files[file_name] then files[file_name]+=1 else 1 end)

	# Add the status code to the hash if not there; increment otherwise
	counts[stat_code] = (if counts[stat_code] then counts[stat_code]+=1 else 1 end)

	# Check if we're on a new date; if so, add a new array to the hash
	unless requests_by_month[mon_year] then requests_by_month[mon_year] = [] end

	# Add the whole line into the array for that day
	requests_by_month[mon_year].push(line)

end
puts "\n\n"

# Sort the hash with file request counts to find the highest (and lowest)
sorted_files = files.sort_by { |k, v| -v }

#
# Calculate a grand total by adding the counts from each month
#   Also, write the lines out to per-month log entries`
#
grand_total = 0
# Ensure that the directory for my new log files exists
Dir.mkdir(LOG_PATH) unless File.exists?(LOG_PATH)
# Loop through the 'requests_by_month' hash
requests_by_month.each do |key, arr|
	grand_total += arr.count
	file_name = LOG_PATH + key + '.log'
	# Open a new file in the log directory for this month
	File.open(file_name, "w+") do |f|
		# Dump all the lines in the array to the new file
		f.puts(arr)
	end
	puts "  Writing new file to disk: #{file_name} (#{arr.count} entries)"
end

#
# Sum all the status codes to get the totals
#
totals_3xx = 0
totals_4xx = 0
totals_5xx = 0
counts.each do |code, count|
	if code[0] == "3" then totals_3xx += count end
	if code[0] == "4" then totals_4xx += count end
	if code[0] == "5" then totals_5xx += count end
end
err_pct = (totals_4xx.to_f / grand_total.to_f * 100).to_i
red_pct = (totals_3xx.to_f / grand_total.to_f * 100).to_i

# Write the errors to a log file
File.open("error.log", "w+") do |f|
	f.puts(errors)
end

# Write all the data out to the screen
puts "\n\n\n"
puts "--- STATS ---"
puts "Total number of requests: #{grand_total}"
puts "Number of requests per month: "
requests_by_month.each do |mon, lines|
	puts "    #{mon}: #{lines.count}"
end
puts "Average requests per month: #{grand_total / requests_by_month.count}"
puts "Most commonly requested file: #{sorted_files[0]}"
puts "Least requested file: #{sorted_files[sorted_files.count-1]}"
puts "Percentage of errors: #{err_pct}% (#{totals_4xx} total)"
puts "Percentage of redirects: #{red_pct}% (#{totals_3xx} total)"

puts "\n\n--- ERRORS ---"
puts "Encountered parsing errors on #{errors.count} lines."
puts "  Output written to error.log \n\n"
