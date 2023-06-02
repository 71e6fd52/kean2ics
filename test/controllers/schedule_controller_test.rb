# frozen_string_literal: true

require 'test_helper'

class ScheduleControllerTest < ActionDispatch::IntegrationTest
  test 'should get login' do
    get schedule_login_url
    assert_response :success
  end

  test 'should get generate' do
    get schedule_generate_url
    assert_response :success
  end
end
