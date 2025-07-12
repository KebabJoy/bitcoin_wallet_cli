# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Wallet::TransactionBuilder do
  subject { described_class.new(key_pair:, utxo_repo:, tx_repo:) }

  let(:tx_repo) { instance_double(Infrastructure::TransactionRepository) }
  let(:utxo_repo) { instance_double(Infrastructure::UtxoRepository) }
  let(:key_pair) { Wallet::Domain::KeyPair.new(Bitcoin::Key.generate) } # I don't wanna stub a DTO
  let(:addressee) { Bitcoin::Key.generate.to_p2pkh }

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
      let(:fee) { Wallet::TransactionBuilder::FIXED_FEE_SATS }
      let(:input_value) { 2_000 }
      let(:change) { input_value - amount - fee }
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
        txid = subject.send_to(addressee, amount)

        expect(txid).to eq(txid)

        expect(tx_repo).to have_received(:broadcast_tx).once
        expect(broadcasted_hex.first).to be_a(String)

        raw_tx = Bitcoin::Tx.parse_from_payload(broadcasted_hex.first.htb)

        expect(raw_tx.in.size).to eq(1)
        expect(raw_tx.out.size).to eq(2)

        values = raw_tx.out.map(&:value)
        expect(values).to contain_exactly(amount, change)
        expect(values.sum).to eq(input_value - fee)
      end
    end
  end
end
