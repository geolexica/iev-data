require "spec_helper"

RSpec.describe Iev::Termbase::DbWriter do
  let(:instance) { described_class.new(db) }
  let(:db) { Sequel.sqlite }

  describe "#import_spreadsheet" do
    subject { instance.method(:import_spreadsheet) }

    it "creates concepts table" do
      silence_output_streams { subject.(sample_file) }
      expect(db.table_exists?(:concepts)).to be(true)
    end

    it "fills concepts table with data" do
      silence_output_streams { subject.(sample_file) }

      eng_row = db[:concepts].where(IEVREF: "103-01-01", LANGUAGE: "en").first
      kor_row = db[:concepts].where(IEVREF: "103-01-01", LANGUAGE: "ko").first

      expect(eng_row).not_to be(nil)
      expect(kor_row).not_to be(nil)

      expect(eng_row[:TERM]).to eq("function")
      expect(eng_row[:DEFINITION]).to start_with("See")
      expect(kor_row[:TERM]).to eq("함수")
      expect(kor_row[:SOURCE]).not_to be(nil)
    end
  end

  def sample_file
    Iev.root_path.join("spec", "fixtures", "sample-file.xlsx")
  end
end
