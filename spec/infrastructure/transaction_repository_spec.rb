# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Infrastructure::TransactionRepository do
  subject(:transaction_repository) { described_class.new(data_gateway: mempool_client) }

  let(:mempool_client) { instance_double(Infrastructure::MempoolClient) }

  describe '#broadcast_tx' do
    let(:tx_hex) { SecureRandom.hex }

    before do
      allow(mempool_client).to receive(:post).and_return({ success: true })
    end

    it 'returns response of mempool_client' do
      expect(mempool_client).to receive(:post).with('/tx', tx_hex)

      expect(transaction_repository.broadcast_tx(tx_hex)).to eq(success: true)
    end
  end

  describe '#get_tx' do
    let(:tx_id) { SecureRandom.uuid }

    before do
      allow(mempool_client).to receive(:get).and_return({ success: true })
    end

    it 'returns response of mempool_client' do
      expect(mempool_client).to receive(:get).with("/tx/#{tx_id}")
      expect(transaction_repository.get_tx(tx_id)).to eq(success: true)
    end
  end
end
