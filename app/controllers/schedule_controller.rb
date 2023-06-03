# frozen_string_literal: true

class ScheduleController < ApplicationController
  def login
    return if session[:data].nil?

    redirect_to action: 'choose'
  end

  def perform_login
    data = Kean.get_json(params[:username], params[:password])
    if data.is_a?(Kean::Error)
      flash[:error] = data.message
      redirect_to action: 'login'
    else
      session[:data] = data
      session[:last_update] = Time.current
      redirect_to action: 'choose'
    end
  end

  def logout
    reset_session
    redirect_to action: 'login'
  end

  def generate
    ical = Kean.generate_ical(session[:data], params[:term])
    if ical.is_a?(Kean::Error)
      flash[:error] = ical.message
      redirect_to action: 'choose'
    else
      send_data ical, filename: "#{params[:term]}.ics"
    end
  end

  def choose
    return unless session[:data].nil?

    redirect_to action: 'login'
  end
end
