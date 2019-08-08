# frozen_string_literal: true

# Web service which handle incoming calls.
# We need to disable verifying the Rails authenticity token.
# to do : securing webhooks using Rack Middleware
# link : https://www.twilio.com/blog/2014/09/securing-your-ruby-webhooks-with-rack-middleware.html
class IvrController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_call, only: %i[voice_mail_redirection phone_redirection]

  # A new incoming call always reachs
  # at first process_incoming_call method
  # Webhook configuration: ivr/process_incoming_call
  def process_incoming_call
    @call = Call.new(call_params)
    begin
      @call.save
    rescue => e
      puts "Rescued: #{e}"
    end
    give_choice
  end

  def give_choice
    resp = IncomingCallManager.new(set_params, path_params).give_choice
    render xml: resp
  end

  def process_selected_choice
    resp = IncomingCallManager.new(set_params, path_params).process_selected_choice
    render xml: resp
  end

  def voice_mail_redirection
    resp = IncomingCallManager.new(set_params, path_params).end_voice_mail
    begin
      @call.update(forwarding: 2,
        status: 'completed',
        duration: set_duration)
      Record.create(record_params)
    rescue => e
      puts "Rescued: #{e}"
    end
    render xml: resp
  end

  def phone_redirection
    @call.update(forwarding: 1,
                 status: 'completed',
                 duration: set_duration) if @call
    resp = IncomingCallManager.new(set_params, path_params).end_phone_call
    render xml: resp
  end

  private

  def set_params
    params.permit(:From, :Direction, :Called, :msg,
                  :CallStatus, :Digits, :RecordingSid,
                  :CallSid, :RecordingDuration, :RecordingUrl)
  end

  def call_params
    params = set_params
    {
      from: params[:From],
      direction: params[:Direction],
      called: params[:Called],
      sid: params[:CallSid],
      status: params[:CallStatus]
    }
  end

  def record_params
    params = set_params
    {
      call_id: @call.id,
      sid: params[:RecordingSid],
      duration: params[:RecordingDuration],
      link: params[:RecordingUrl]
    }
  end

  def path_params
    {
      process_selected_choice_path: url_for(action: 'process_selected_choice', controller: 'ivr'),
      give_choice_path: url_for(action: 'give_choice', controller: 'ivr'),
      voice_mail_redirection_path: url_for(action: 'voice_mail_redirection', controller: 'ivr'),
      phone_redirection_path: url_for(action: 'phone_redirection', controller: 'ivr')
    }
  end

  def set_call
    @call = Call.find_by_sid(params[:CallSid])
  end

  def set_duration
    (Time.now.utc - @call.created_at).round(0)
  end
end
