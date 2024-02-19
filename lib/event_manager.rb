require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

puts 'Event manager initialized'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

class EventManager
  attr_reader :civic_info, :template_letter

  def initialize
    @civic_info = make_api
    @template_letter = File.read('form_letter.erb')
  end

  def make_api
    civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
    civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
    civic_info
  end

  def legislators_by_zipcode(zipcode)
    legislators = []
    begin
      legislators = civic_info.representative_info_by_address(
        address: zipcode,
        levels: 'country',
        roles: %w[legislatorUpperBody legislatorLowerBody]
      )
      legislators = legislators.officials
    rescue StandardError => _e
      'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
    end
  end

  def save_letter(id, personal_letter)
    Dir.mkdir('output') unless Dir.exist?('output')
    filename = "output/thanks_#{id}.html"

    File.open(filename, 'w') do |file|
      file.puts personal_letter
    end
  end

  def clean_phone_number(number)
    number = number.to_s.gsub(/\D+/, '') # Remove all non-digits, for brackets, dashes etc

    if number.nil?
    # do nothing
    # If the phone number is less than 10 digits, assume that it is a bad number
    # If the phone number is more than 11 digits, assume that it is a bad number
    elsif number.length < 10 || number.length > 11
      number = nil
    elsif number.length == 11
      if number[0] == '1'
        # If the phone number is 11 digits and the first number is 1, trim the 1 and use the remaining 10 digits
        # do nothing
      else
        # If the phone number is 11 digits and the first number is not 1, then it is a bad number
        number = nil
      end
    end
    number
  end

  def show_info
    contents = CSV.open('event_attendees.csv', headers: true, header_converters: :symbol)
    contents.each do |row|
      id = row[0]
      name = row[:first_name]
      zipcode = clean_zipcode(row[:zipcode])
      legislator_names = legislators_by_zipcode(zipcode)

      erb_template = ERB.new template_letter
      personal_letter = erb_template.result(binding)

      save_letter(id, personal_letter)

      cleaned_number = clean_phone_number(row[:homephone])
      puts "#{id} #{name} #{cleaned_number}"
    end
  end
end

event = EventManager.new
event.show_info
