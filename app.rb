require 'awesome_print'
require 'sinatra/base'
require 'rack/contrib'
require 'ynab'
require 'logger'
require 'sinatra/custom_logger'

class SyncYnabApp < Sinatra::Base
  use Rack::JSONBodyParser
  set :logger, Logger.new(STDOUT)

  before do
    content_type :json
  end

  post "/transactions" do
    logger.info params

    notification_text = params[:notification_text]

    unless notification_text.include? "Sua compra foi aprovada"
      halt 400, { ok: false, message: "Invalid payload." }.to_json
    end

    amount = notification_text.scan(/[0-9]+,[0-9]{2}/)[0].gsub(',','.').to_f
    payee = notification_text.scan(/(?<=em)(.*\n?)/)[0][0].strip.chomp('.')

    ynab = YNAB::API.new(ENV['YNAB_API_KEY'])
    budget_id = ENV['YNAB_BUDGET_ID']
    account_id = ENV['NUCONTA_ACCOUNT_ID']

    transaction_data = {
      transaction: {
        account_id: account_id,
        date: Time.now.to_s,
        payee_name: payee,
        cleared: "Cleared",
        approved: true,
        amount: (amount * 1000).to_i * -1
      }
    }

    begin
      ynab.transactions.create_transaction(budget_id, transaction_data)
      halt 201, { ok: true, message: 'Transação criada no YNAB - Compra no débito.' }.to_json
    rescue => e
      logger.info "ERROR: id=#{e.id}; name=#{e.name}; detail: #{e.detail}"
      halt 400, { ok: false, message: "Erro: #{e.message}" }.to_json
    end

  end
end