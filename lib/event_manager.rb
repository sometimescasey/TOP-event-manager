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
    rescue StandardError => e
      print(e)
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

  def show_info
    contents = CSV.open('event_attendees.csv', headers: true, header_converters: :symbol)
    contents.each do |row|
      id = row[0]
      name = row[:first_name]
      zipcode = clean_zipcode(row[:zipcode])
      legislator_names = legislators_by_zipcode(zipcode)

      erb_template = ERB.new template_letter
      personal_letter = erb_template.result(binding)

      puts personal_letter

      save_letter(id, personal_letter)
    end
  end
end

event = EventManager.new
event.show_info
