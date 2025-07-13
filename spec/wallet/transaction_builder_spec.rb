# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Wallet::TransactionBuilder do
  subject { described_class.new(key_pair:, utxo_repo:, tx_repo:) }

  let(:tx_repo) { instance_double(Infrastructure::TransactionRepository) }
  let(:utxo_repo) { instance_double(Infrastructure::UtxoRepository) }
  let(:key_pair) { Wallet::Domain::KeyPair.new(Bitcoin::Key.generate) } # I don't wanna stub a DTO
  let(:addressee) { Bitcoin::Key.generate.to_p2wpkh }

  def utxo(value)
    Infrastructure::UTXO.new(
      txid: SecureRandom.hex(32),
      vout: 0,
      value: value,
      confirmed: true
    )
  end

  describe '#send_to' do
    context 'when not enough money' do
      before do
        allow(utxo_repo).to receive(:confirmed_for_address)
          .with(key_pair.address)
          .and_return([utxo(400)])
      end

      it 'raises an error' do
        expect { subject.send_to(addressee, 500) }
          .to raise_error(/Not enough money/)
      end
    end

    context 'with valid input' do
      let(:amount) { 500 }
      let(:input_value) { 2_000 }
      let(:broadcasted_hex) { [] }
      let(:txid) { SecureRandom.hex(32) }

      before do
        allow(utxo_repo).to receive(:confirmed_for_address)
                              .with(key_pair.address)
                              .and_return([utxo(input_value)])

        allow(tx_repo).to receive(:broadcast_tx) do |hex|
          broadcasted_hex << hex
          txid
        end
      end

      it 'builds a valid transaction and sends it to repo' do
        txid_result = subject.send_to(addressee, amount)

        expect(txid_result).to eq(txid)
        expect(tx_repo).to have_received(:broadcast_tx).once

        raw_tx = Bitcoin::Tx.parse_from_payload(broadcasted_hex.first.htb)

        values = raw_tx.out.map(&:value)
        expect(values).to include(amount)
        fee = input_value - values.sum

        expect(fee).to be > 0
        expect(fee).to be < 500

        change = (values - [amount]).first
        expect(change).to be >= Wallet::TransactionBuilder::DEFAULT_DUST_RATE
      end
    end
  end
end
