# frozen_string_literal: true

class ScheduleController < ApplicationController
  def login; end

  def perform_login
    data = helpers.get_json(params[:username], params[:password])
    if data.is_a?(ScheduleHelper::Error)
      flash[:error] = data.message
      redirect_to action: 'login'
    else
      session[:data] = data
      redirect_to action: 'choose'
    end
  end

  def generate
    ical = helpers.generate_ical(session[:data], params[:term])
    if ical.is_a?(ScheduleHelper::Error)
      flash[:error] = data.message
      redirect_to action: 'choose'
    else
      send_data ical, filename: "#{params[:term]}.ics"
    end
  end

  def choose; end

  def choose_post
    # session[:term] = params[:term]
    redirect_to action: 'generate', term: params[:term]
  end
end
