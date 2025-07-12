#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pry'
require_relative 'lib/bitcoin_wallet'

Bitcoin.chain_params = :signet

COMMANDS = %w[generate balance transfer].freeze

cmd = ARGV.shift
unless COMMANDS.include?(cmd)
  abort <<~USAGE
    Usage:
      ruby wallet.rb generate
      ruby wallet.rb balance
      ruby wallet.rb transfer DEST_ADDRESS AMOUNT_SATS
  USAGE
end

key_repository = Wallet::FileKeyRepository.new
key_pair = key_repository.load

case cmd
when 'generate'
  key_pair = Wallet::Domain::KeyPair.new(Bitcoin::Key.generate)
  key_repository.save(key_pair)

  puts "Address: #{key_pair.address}"
  puts 'Private key saved in data/wallet.json'
when 'balance'
  balance = Infrastructure::UtxoRepository.new.confirmed_balance(key_pair.address)
  puts "Balance for #{key_pair.address}: #{balance} sats"
when 'transfer'
  dest = ARGV.shift
  amount = ARGV.shift.to_i
  abort 'Need DEST_ADDRESS and AMOUNT_SATS' if dest.nil? || amount.zero?

  builder = Wallet::TransactionBuilder.new(key_pair: key_pair)
  txid = builder.send_to(dest, amount)
  puts "Broadcasted! TXID: #{txid}"
end
