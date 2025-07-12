# frozen_string_literal: true

require 'rspec'

RSpec.describe Infrastructure::UtxoRepository do
  subject(:repository) { described_class.new(data_gateway:) }

  let(:data_gateway) { instance_double(Infrastructure::MempoolClient) }
  let(:address) { 'test' }
  let(:utxo_api_response) do
    [
      { txid: 'test', vout: 'test', value: 1, status: { confirmed: false } },
      { txid: 'test', vout: 'test', value: 1, status: { confirmed: true } }
    ]
  end
  let(:utxo_list) do
    utxo_api_response.map do |hash|
      Infrastructure::UTXO.new(
        txid: hash[:txid],
        vout: hash[:vout],
        value: hash[:value],
        confirmed: hash[:status][:confirmed]
      )
    end
  end

  before do
    allow(data_gateway).to receive(:get).and_return(utxo_api_response)
  end

  describe '#all_for_address' do
    it 'calls mempool api' do
      expect(data_gateway).to receive(:get).with("address/#{address}/utxo")
      expect(repository.all_for_address(address)).to match(utxo_list)
    end
  end

  describe '#confirmed_for_address' do
    it 'calls mempool api' do
      expected_result = utxo_list.select(&:confirmed)
      expect(data_gateway).to receive(:get).with("address/#{address}/utxo")
      expect(repository.confirmed_for_address(address)).to match(expected_result)
    end
  end

  describe '#confirmed_balance' do
    it 'calls mempool api' do
      expected_result = utxo_list.select(&:confirmed).sum(&:value)
      expect(data_gateway).to receive(:get).with("address/#{address}/utxo")
      expect(repository.confirmed_balance(address)).to match(expected_result)
    end
  end
end
