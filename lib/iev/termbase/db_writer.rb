module Iev
  module Termbase
    class DbWriter
      using DataConversions

      attr_reader :db

      def initialize(db)
        @db = db
      end

      def import_spreadsheet(file)
        workbook = open_workbook(file)
        row_enumerator = workbook.sheets.first.simple_rows.each

        title_row = row_enumerator.next
        symbolized_title_row = title_row.compact.transform_values(&:to_sym)

        create_table(symbolized_title_row.values)

        loop do
          row = row_enumerator.next
          next if row.empty?
          data = prepare_data(row, symbolized_title_row)
          display_progress(data)
          insert_data(data)
        end
      end

      private

      def open_workbook(file)
        puts "Opening spreadsheet..."
        Creek::Book.new(file)
      end

      def create_table(column_names)
        db.create_table!(:concepts) do
          column_names.each { |cn| column cn, String }
          primary_key column_names[0..1], name: :iev_pk
          index column_names[0]
          index column_names[1]
        end
      end

      # Replaces A, B, C… keys with real column names and sanitizes cell
      # content.
      def prepare_data(row, title_row)
        data = row.dup
        data.transform_keys! { |k| title_row[k] }
        data.transform_values! { |v| v&.sanitize }
        data
      end

      def display_progress(data)
        ievref = data[:IEVREF]
        lang = data[:LANGUAGE].to_three_char_code
        print "\rImporting term #{ievref} (#{lang})... "
      end

      def insert_data(data)
        db[:concepts].insert(data)
      rescue Sequel::UniqueConstraintViolation
        puts "SKIPPING, duplicated (TERMID, LANGUAGE) pair"
      end
    end
  end
end