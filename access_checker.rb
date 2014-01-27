# Tested in JRuby 1.7.3
# Written by Kristina Spurgin
# Last updated: 20130412

# Usage:
# jruby -S access_checker.rb [inputfilelocation] [outputfilelocation]

# Input file: 
# .csv file with: 
# - one header row
# - any number of columns to left of final column
# - one URL in final column

# Output file: 
# .csv file with all the data from the input file, plus a new column containing
#   access checker result

require 'celerity'
require 'csv'
require 'highline/import'
require 'open-uri'

  puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
  puts "What platform/package are you access checking?"
  puts "Type one of the following:"
  puts "  apb    : Apabi ebooks"
  puts "  asp    : Alexander Street Press links"
  puts "  duphw  : Duke University Press (via HighWire)"
  puts "  ebr    : Ebrary links"
  puts "  ebs    : EBSCOhost ebook collection"
  puts "  end    : Endeca - Check for undeleted records"
  puts "  nccorv : NCCO - Check for related volumes"
  puts "  scid   : ScienceDirect ebooks (Elsevier)"
  puts "  spr    : SpringerLink links"
  puts "  skno   : SAGE Knowledge links"
  puts "  srmo   : SAGE Research Methods Online links"
  puts "  ss     : SerialsSolutions links"
  puts "  upso   : University Press (inc. Oxford) Scholarship Online links"
  puts "  wol    : Wiley Online Library"
  puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

  package = ask("Package?  ")

  puts "\nPreparing to check access...\n"

input = ARGV[0]
output = ARGV[1]

csv_data = CSV.read(input, :headers => true)

counter = 0
total = csv_data.count

headers = csv_data.headers
headers << "access"

CSV.open(output, "a") do |c|
  c << headers
end

b = Celerity::Browser.new(:browser => :firefox)
#b = Celerity::Browser.new(:browser => :firefox, :log_level => :all)

csv_data.each do |r|
  row_array = r.to_csv.parse_csv
  url = row_array.pop
  rest_of_data = row_array

  b.goto(url)
  page = b.html

  if package == "apb"
    if page.match(/type="onlineread"/)
      access = "Access probably ok"
    else
      access = "check"
    end  
      
  elsif package == "asp"
    if page.include?("Page Not Found")
      access = "not found"
    elsif page.include?("error")
      access = "error"
    elsif page.include?("Browse")
        access = "access ok"
    else
      access = "check"
    end

  elsif package == "duphw"
    if page.include?("DOI Not Found")
      access = "not found - DOI error"
    else
      # I could find nothing on the ebook landing page to differentiate those to which we have full text access from those to which we do not.
      # This requires an extra step of having the checker visit one of the content pages, and testing whether one gets the content, or a log-in page
      url_title_segment = page.match(/http:\/\/reader\.dukeupress\.edu\/([^\/]*)\/\d+/).captures[0]
      content_url = "http://reader.dukeupress.edu/#{url_title_segment}/25"
  
      # Celerity couldn't handle opening the fulltext content pages that actually work,
      #  so I switch here to using open-uri to grab the HTML
  
      thepage = ""
      open(content_url) {|f|
        f.each_line {|line| thepage << line}
        }
      
      if thepage.include?("Log in to the e-Duke Books Scholarly Collection site")
        access = "no access"
      elsif thepage.include?("t-page-nav-arrows")
        access = "full text access"
      else
        access = "check access manually"
      end
    end
  
  
  elsif package == "ebr"
    if page.include?("Document Unavailable\.")
      access = "no access"
    elsif page.include?("Date Published")
        access = "access"
    else
      access = "check"
    end

  elsif package == "ebs"
    if page.match(/class="std-warning-text">No results/)
      access = "no access"
    elsif page.include?("eBook Full Text")
        access = "access"
    else
      access = "check"
    end

  elsif package == "end"
    if page.include?("Invalid record")
      access = "deleted OK"
    else
      access = "possible ghost record - check"
    end    
    
  elsif package == "nccorv"
    if page.match(/<div id="relatedVolumes">/)
      access = "related volumes section present"
    else
      access = "no related volumes section"
    end

  elsif package == "scid"
    if page.match(/<td class=nonSerialEntitlementIcon><span class="sprite_nsubIcon_sci_dir"/)
      access = "not full text"
    elsif page.match(/title="You are entitled to access the full text of this document"/)
      access = "full text"
    else
      access = "check"
    end    

  elsif package == "skno"
    if page.include?("Page Not Found")
      access = "not found"
      elsif page.include?("Add to My Lists")
        access = "found"
    else
      access = "check"
    end

  elsif package == "spr"
    if page.match(/viewType="Denial"/) != nil
      access = "restricted"
      elsif page.match(/viewType="Full text download"/) != nil
        access = "full"
      elsif page.match(/DOI Not Found/) != nil
        access = "DOI error"
      elsif page.include?("Bookshop, Wageningen")
        access = "wageningenacademic.com"
    else
      access = "check"
    end    
    
  elsif package == "srmo"
    if page.include?("Page Not Found")
      access = "not found"
      elsif page.include?("Add to Methods List")
        access = "found"
    else
      access = "check"
    end

  elsif package == "ss"
    if page.include? "SS_NoJournalFoundMsg"
      access = "no access"
    elsif page.include? "SS_Holding"
      access = "access"
    else
      access = "check manually"
    end

  elsif package == "upso"
    if page.include?("<div class=\"contentItem\">")
      access = "access ok"
    else
      access = "check"
    end

  elsif package == 'wol'
    if page.include?("You have full text access to this content")
      access = "full"
    elsif page.include?("DOI Not Found")
      access = "DOI error"
    else
      access = "check"
    end
  end

  CSV.open(output, "a") do |c|
    c << [rest_of_data, url, access].flatten
  end

  counter += 1
  puts "#{counter} of #{total}, access = #{access}"
  
  sleeptime = 1
  sleep sleeptime
end
