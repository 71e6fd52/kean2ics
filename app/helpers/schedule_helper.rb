# frozen_string_literal: true

# require 'icalendar'
# require 'json'
# require 'nokogiri'
require 'net/http'
require 'uri'

module ScheduleHelper
  class HttpWithCookies
    attr_reader :cookies

    def initialize
      @cookies = []
    end

    def get(uri, headers = {}, limit: 10)
      raise ArgumentError, 'HTTP redirect too deep' if limit.zero?

      uri = URI(uri)

      headers = default_headers.merge(headers)
      response = Net::HTTP.get_response(URI(uri), headers)
      update_cookies(response)
      if response.is_a?(Net::HTTPRedirection)
        get(uri.merge(response['location']), limit: limit - 1)
      else
        response
      end
    end

    def post(uri, data, headers = {}, limit: 10)
      raise ArgumentError, 'HTTP redirect too deep' if limit.zero?

      uri = URI(uri)

      headers = default_headers.merge(headers)
      response = Net::HTTP.post(uri, data, headers)
      update_cookies(response)
      if response.is_a?(Net::HTTPRedirection)
        get(uri.merge(response['location']), limit: limit - 1)
      else
        response
      end
    end

    private

    def default_headers
      {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/115.0',
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language' => 'en-US,en;q=0.5',
        'Cookie' => @cookies.join('; '),
        'Upgrade-Insecure-Requests' => '1',
        'Referer' => 'https://selfservice.kean.edu/Student',
      }
    end

    def update_cookies(response)
      new_cookies = response.get_fields('set-cookie')
      return unless new_cookies

      new_cookies.each do |cookie|
        cookie = cookie.split(';').first
        cookie_name = cookie.split(';').first.split('=').first
        @cookies.delete_if { |c| c.split(';').first.split('=').first == cookie_name }
        @cookies << cookie
      end
    end
  end
  WEEKDAYS = %w[SU MO TU WE TH FR SA].freeze

  def get_json(username, password)
    client = HttpWithCookies.new
    response = client.get('https://selfservice.kean.edu/Student/Account/login')
    html = Nokogiri::HTML(response.body)

    form_data = {
      '__RequestVerificationToken' => html.xpath('//input[@name="__RequestVerificationToken"]').first['value'],
      'returnUrl' => '',
      'performSamlLogin' => '',
      'UserName' => username,
      'Password' => password,
    }
    encoded_form_data = URI.encode_www_form(form_data)

    response = client.post('https://selfservice.kean.edu/Student/Account/Login?returnUrl=%252fStudent%252fPlanning%252fDegreePlans', encoded_form_data, {
                             'Content-Type' => 'application/x-www-form-urlencoded',
                           })

    user_id = response.body.match(/var currentUserId = "(\d+)"/)[1]

    ajax_headers = {
      '__RequestVerificationToken' => Nokogiri::HTML(response.body).xpath('//input[@name="__RequestVerificationToken"]').first['value'],
      'X-Requested-With' => 'XMLHttpRequest',
      'Accept' => 'application/json, text/javascript, */*; q=0.01',
      'Referer' => 'https://selfservice.kean.edu/Student/Planning/DegreePlans',
    }
    response = client.get(
      "https://selfservice.kean.edu/Student/Planning/DegreePlans/CurrentAsync?studentId=#{user_id}", ajax_headers
    )

    JSON.parse(response.body)['DegreePlan']['Terms']
        .delete_if { _1['PlannedCourses'].nil? || _1['PlannedCourses'].empty? }
        .map do |term|
      term.slice('Code', 'Description',
                 'PlannedCourses').tap do |term|
        term['PlannedCourses'].map! do |course|
          course.slice('Section', 'TitleDisplay').tap do |course|
            course['Section'].slice!('PlannedMeetings', 'Faculty')
            course['Section']['PlannedMeetings'].map! do |meeting|
              meeting.slice('Days', 'StartTime', 'EndTime', 'MeetingLocation',
                            'StartDateString', 'EndDateString')
            end
          end
        end
      end
    end
  end

  def generate_ical(json, term)
    courses = json.filter { _1['Code'] == term }.first['PlannedCourses']

    tz = { 'tzid' => 'Asia/Shanghai' }

    # Create a calendar with an event (standard method)
    cal = Icalendar::Calendar.new

    courses.each do |course|
      course['Section']['PlannedMeetings'].each do |meeting|
        start_date = Date.strptime(meeting['StartDateString'], '%m/%d/%Y')
        start_date += (meeting['Days'].min - start_date.wday) % 7 # first day of class

        cal.event do |e|
          e.dtstart = Icalendar::Values::DateTime.new(
            DateTime.parse("#{start_date.strftime('%F')} #{meeting['StartTime']}"), tz
          )
          e.dtend = Icalendar::Values::DateTime.new(
            DateTime.parse("#{start_date.strftime('%F')} #{meeting['EndTime']}"), tz
          )
          e.summary = course['TitleDisplay'].tr('*', ' ')
          e.description = course['Section']['Faculty'].join('; ')
          e.location = meeting['MeetingLocation']
                       .gsub(/^WKU /, '')
                       .gsub(/Gehekai Hall/, 'GHK')
                       .gsub(/General Education Hall/, 'GEH')
          byday = meeting['Days'].map { WEEKDAYS[_1] }.join(',')
          e.rrule = Icalendar::Values::Recur.new(
            "FREQ=WEEKLY;UNTIL=#{Date.strptime(meeting['EndDateString'],
                                               '%m/%d/%Y').strftime('%Y%m%d')};BYDAY=#{byday}",
          )

          e.alarm do |a|
            a.summary = 'Notification'
            a.trigger = '-P0DT0H15M0S' # 1 day before
          end
        end
      end
    end

    cal.to_ical
  end
end
