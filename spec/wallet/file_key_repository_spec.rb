# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Wallet::FileKeyRepository do
  subject(:repository) { described_class.new(temp_path) }

  let(:temp_path) { 'tmp/test_wallet.json' }
  let(:key) { Bitcoin::Key.generate }
  let(:key_pair) { Wallet::Domain::KeyPair.new(key) }

  before do
    FileUtils.mkdir_p(File.dirname(temp_path))
    FileUtils.rm_f(temp_path)
  end

  after do
    FileUtils.rm_f(temp_path)
  end

  describe '#persisted?' do
    context 'when the file does not exist' do
      it 'returns false' do
        expect(repository.persisted?).to be_falsey
      end
    end

    context 'when the file exists' do
      it 'returns true' do
        repository.save(key_pair)
        expect(repository.persisted?).to be_truthy
      end
    end
  end

  describe '#save and #load' do
    it 'saves and loads a key pair correctly' do
      repository.save(key_pair)
      loaded = repository.load

      expect(loaded).to be_a(Wallet::Domain::KeyPair)
      expect(loaded.address).to eq(key_pair.address)
      expect(loaded.key.to_wif).to eq(key_pair.key.to_wif)
    end

    context 'when the file does not exist' do
      it 'returns' do
        expect(repository.load).to be_nil
      end
    end
  end
end
