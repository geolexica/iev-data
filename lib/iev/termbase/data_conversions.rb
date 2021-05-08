# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

module IEV
  module Termbase
    module DataConversions
      HTML_ENTITIES_DECODER = HTMLEntities.new(:expanded)
      HTML_ENTITIES_MUTEX = Mutex.new

      refine String do
        def decode_html!
          replace(decode_html)
          nil
        end

        def decode_html
          # I don't remember why exactly, but I consider HTMLEntites gem
          # thread-unsafe.
          # See: https://github.com/glossarist/iev-data/issues/174.
          HTML_ENTITIES_MUTEX.synchronize do
            HTML_ENTITIES_DECODER.decode(self)
          end
        end

        # Normalize various encoding anomalies like `\uFEFF` in strings
        def sanitize!
          unicode_normalize!
          gsub!("\uFEFF", "")
          gsub!("\u2011", "-")
          gsub!("\u00a0", " ")
          gsub!(/[\u2000-\u2006]/, " ")
          strip!
          nil
        end

        # @see sanitize!
        def sanitize
          dup.tap(&:sanitize!)
        end

        def to_three_char_code
          IEV::Termbase::Iso639Code.three_char_code(self).first
        end
      end
    end
  end
end
