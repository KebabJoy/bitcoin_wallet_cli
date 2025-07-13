# frozen_string_literal: true

module Wallet
  # Bitcoin transactions builder
  class TransactionBuilder
    DUMMY_BINARY_VALUE = SecureRandom.random_bytes(32)
    DUMMY_KEY_HASH = SecureRandom.random_bytes(20)
    DUMMY_P2WPKH_SCRIPT = Bitcoin::Script.to_p2wpkh(DUMMY_KEY_HASH)
    SAFETY_MARGIN_SATS = 2
    DUMMY_EMISSION_VALUE = 17
    DEFAULT_FEE_RATE = 1
    DEFAULT_DUST_RATE  = 546

    # @param key_pair [Wallet::KeyManager] provides key & address
    # @param utxo_repo [Infrastructure::UtxoRepository]
    # @param tx_repo [Infrastructure::TransactionRepository]
    def initialize(key_pair:,
                   utxo_repo: Infrastructure::UtxoRepository.new,
                   tx_repo: Infrastructure::TransactionRepository.new)
      @key_pair = key_pair
      @utxo_repo = utxo_repo
      @tx_repo = tx_repo
    end

    # @param dest_address [String] base58 or bech32 Signet address
    # @param amount_sats [Integer]
    # @return [String] txid
    def send_to(dest_address, amount_sats)
      utxos = utxo_repo.confirmed_for_address(key_pair.address)
      relevant_utxo, change = select_utxos(utxos, amount_sats)
      raise 'Not enough money👎👎👎' if relevant_utxo.nil?

      tx = build_tx(relevant_utxo, dest_address, amount_sats, change)
      tx_repo.broadcast_tx(tx.to_hex.to_s)
    end

    private

    attr_reader :key_pair, :utxo_repo, :tx_repo

    # @return [Array<(Array<Infrastructure::UTXO>, Integer), nil>]
    def select_utxos(utxos, amount_sats)
      selected = []
      total = 0

      utxos.sort_by(&:value).each do |utxo|
        selected << utxo
        total += utxo.value

        est_fee = estimate_fee(selected.size, 2)
        next unless total >= amount_sats + est_fee

        change = total - amount_sats - est_fee
        change = 0 if change < DEFAULT_DUST_RATE

        return [selected, change]
      end

      [nil, nil]
    end

    def estimate_fee(input_count, output_count)
      tx = Bitcoin::Tx.new

      input_count.times do
        tx.in << Bitcoin::TxIn.new(out_point: Bitcoin::OutPoint.new(DUMMY_BINARY_VALUE, 0))
      end

      output_count.times do
        tx.out << Bitcoin::TxOut.new(value: DUMMY_EMISSION_VALUE, script_pubkey: DUMMY_P2WPKH_SCRIPT)
      end

      dummy_sig = ['00' * 72, '00' * 33]
      tx.in.each { |i| i.script_witness.stack.replace(dummy_sig) }

      (tx.vsize * DEFAULT_FEE_RATE) + SAFETY_MARGIN_SATS
    end

    # @return [Bitcoin::Tx]
    def build_tx(relevant_utxo, dest_address, amount_sats, change_sats) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      tx = Bitcoin::Tx.new

      relevant_utxo.each do |u|
        out_point = Bitcoin::OutPoint.from_txid(u.txid, u.vout)

        tx.in << Bitcoin::TxIn.new(out_point:)
      end

      tx.out << Bitcoin::TxOut.new(value: amount_sats, script_pubkey: Bitcoin::Script.parse_from_addr(dest_address))
      tx.out << Bitcoin::TxOut.new(value: change_sats, script_pubkey: Bitcoin::Script.parse_from_addr(key_pair.address)) if change_sats.positive?

      pk_script = Bitcoin::Script.to_p2wpkh(key_pair.key.hash160)
      relevant_utxo.each_with_index do |utxo, idx|
        sig_hash = tx.sighash_for_input(idx, pk_script, amount: utxo['value'], sig_version: :witness_v0)
        signature = key_pair.key.sign(sig_hash) + [Bitcoin::SIGHASH_TYPE[:all]].pack('C')

        tx.in[0].script_witness.stack << signature
        tx.in[0].script_witness.stack << key_pair.key.pubkey.htb
      end

      tx
    end
  end
end
