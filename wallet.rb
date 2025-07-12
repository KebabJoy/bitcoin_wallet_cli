#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pry'
require 'bitcoin'
require_relative 'lib/wallet/domain/key_pair'
require_relative 'lib/wallet/file_key_repository'
require_relative 'lib/wallet/transaction_builder'
require_relative 'lib/infrastructure/mempool_client'
require_relative 'lib/infrastructure/utxo_repository'
require_relative 'lib/infrastructure/transaction_repository'

Bitcoin.chain_params = :signet

COMMANDS = %w[generate balance send].freeze

cmd = ARGV.shift
unless COMMANDS.include?(cmd)
  abort <<~USAGE
    Usage:
      ruby wallet.rb generate
      ruby wallet.rb balance
      ruby wallet.rb send DEST_ADDRESS AMOUNT_SATS
  USAGE
end

key_repository = Wallet::FileKeyRepository.new
key_pair = key_repository.load

case cmd
when 'generate'
  key_pair = Domain::KeyPair.new(Bitcoin::Key.generate)
  key_repository.save(key_pair)

  puts "Address: #{key_pair.address}"
  puts 'Private key saved in data/wallet.json'
when 'balance'
  balance = Infrastructure::UtxoRepository.new.confirmed_balance(key_pair.address)
  puts "Balance for #{key_pair.address}: #{balance} sats"
when 'send'
  dest = ARGV.shift
  amount = ARGV.shift.to_i
  abort 'Need DEST_ADDRESS and AMOUNT_SATS' if dest.nil? || amount.zero?

  builder = Wallet::TransactionBuilder.new(key_pair: key_pair)
  txid = builder.send_to(dest, amount)
  puts "Broadcasted! TXID: #{txid}"
end
