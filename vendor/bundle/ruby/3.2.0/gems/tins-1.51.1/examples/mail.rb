#!/usr/bin/env ruby

require 'tins'
require 'net/smtp'
require 'time'

class Mail
  extend Tins::DSLAccessor
  include Tins::MethodMissingDelegator::DelegatorModule
  include Tins::BlockSelf

  def initialize(&block)
    super block_self(&block)
    instance_exec(&block)
  end

  dsl_accessor :mail_server, ENV['MAILSERVER'] || 'mail'

  dsl_accessor :body

  if ENV['USER']
    dsl_accessor :from, ENV['USER'] + '@' + (ENV['MAILSERVER'] || 'mail')
  else
    dsl_accessor :from, 'joe@doe.com'
  end

  dsl_accessor :to,       'flori@ping.de'

  dsl_accessor :subject,  'Test Email'

  dsl_accessor :date      do Time.now.rfc2822 end

  def message_id
    key = [ ENV['HOSTNAME'] || 'localhost', $$ , Time.now ].join
    (::Digest::MD5.new << key).to_s
  end

  def msg
    [
      "From: #{from}",
      "To: #{to}",
      "Subject: #{subject}",
      "Date: #{date}",
      "Message-Id: <#{message_id}@#{mail_server}>",
      '',
      body
    ] * "\n"
  end

  def send
    ::Net::SMTP.start(mail_server, 25) do |smtp|
      smtp.send_message msg, from, to
    end
  end
end

def mail(&block)
  Mail.new(&block)
end

def prompt
  STDOUT.print "Send to? "
  STDOUT.flush
  STDIN.gets.strip
end

m = mail do
  subject subject + ': Hi!'
  if rcpt = prompt
    to      rcpt
  end
  body    "Hello, world!\n"
end
m.send
