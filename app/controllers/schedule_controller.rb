# frozen_string_literal: true

class ScheduleController < ApplicationController
  def login; end

  def perform_login
    session[:data] = helpers.get_json(params[:username], params[:password])
    redirect_to action: 'choose'
  end

  def generate
    ical = helpers.generate_ical(session[:data], params[:term])
    # reset_session
    send_data ical, filename: "#{params[:term]}.ics"
  end

  def choose; end

  def choose_post
    # session[:term] = params[:term]
    redirect_to action: 'generate', term: params[:term]
  end
end
