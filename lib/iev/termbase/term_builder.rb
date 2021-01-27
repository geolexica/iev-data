require "pp"

module Iev
  module Termbase
    class TermBuilder
      using DataConversions

      NOTE_REGEX_1 = /Note[\s ]*\d+[\s ]to entry:\s+|Note[\s ]*\d+?[\s ]à l['’]article:[\s ]*|<NOTE\/?>?[\s ]*\d?[\s ]+.*?–\s+|NOTE[\s ]+-[\s ]+/i
      NOTE_REGEX_2 = /\nNOTE\s+/

      def initialize(data)
        @data = data
      end

      def build
        build_term_object
      end

      def self.build_from(data)
        new(data).build
      end

      attr_reader :data

      def find_value_for(key)
        data.fetch(key.to_sym, nil)&.sanitize
      end

      def flesh_date(incomplete_date)
        return incomplete_date if incomplete_date.nil? || incomplete_date.empty?

        # FIXME: this is a terrible assumption but the IEV export only provides
        # year and month
        year, month = incomplete_date.split('-')
        DateTime.parse("#{year}-#{month}-01").to_s
      end

      def build_term_object
        row_term_id = find_value_for("IEVREF")
        row_lang = find_value_for("LANGUAGE").to_three_char_code

        print "\rProcessing term #{row_term_id} (#{row_lang})... "

        Iev::Termbase::Term.new(
          id: row_term_id,
          entry_status: find_value_for("STATUS"),
          classification: find_value_for("SYNONYM1STATUS"),
          date_accepted: flesh_date(find_value_for("PUBLICATIONDATE")),
          date_amended: flesh_date(find_value_for("PUBLICATIONDATE")),
          review_date: flesh_date(find_value_for("PUBLICATIONDATE")),
          review_decision_date: flesh_date(find_value_for("PUBLICATIONDATE")),
          review_decision_event: "published",

          # Beautification
          #
          terms: extract_terms,
          notes: definition_values[:notes].map do |note|
            mathml_to_asciimath(note)
          end,
          examples: definition_values[:examples].map do |example|
            mathml_to_asciimath(example)
          end,
          definition: extract_definition_value,
          authoritative_source: extract_authoritative_source,
          language_code: row_lang,
          superseded_concepts: extract_superseded_concepts,

          # @todo: Unsorted Attributes
          #
          # We need to revisit this attributes and also update
          # the correct mapping with the existing attributes.
          #
          abbrev: nil,
          alt: nil,
          country_code: nil,
          review_indicator: nil,
          authoritative_source_similarity: nil,
          lineage_source: nil,
          review_status: nil,
          review_type: nil,
          review_decision_notes: nil,
        )
      end

      def definition_values
        @definition_values ||= split_definition
      end

      def replace_newlines(input)
        input.gsub('\n', "\n\n").gsub(/<[pbr]+>/, "\n\n").gsub(/\s*\n[\n\s]+/, "\n\n").strip
      end

      def split_definition
        definition = parse_anchor_tag(find_value_for("DEFINITION"))
        definitions = { notes: [], examples: [], definition: nil }

        return definitions unless definition

        definition = replace_newlines(definition)

        # Remove mathml <annotation> tag
        # puts "DDDD"*10
        # # puts definition
        # puts "DDDD"*10
        # definition = parse_anchor_tag(definition)
        # #.to_s.gsub(/<annotation.*?>.*?<\/annotation>/,"").gsub(/<\/?semantics>/,"")
        # puts definition
        # puts "EEEE"*10

        example_block = definition.match(/[\r\n](EXAMPLE|EXEMPLE) (.*?)\r?$/).to_s

        if example_block && !example_block.strip.empty?
          # We only take the latter captured part
          definitions[:examples] = [Regexp.last_match(2).strip]
          definition = definition.gsub("#{Regexp.last_match(1)} #{Regexp.last_match(2)}", "")
        end

        note_split  = definition.split(NOTE_REGEX_1).map do |note|
          note.split(NOTE_REGEX_2)
        end.flatten

        definitions[:definition] = note_split.first
        definitions[:notes] = note_split[1..-1].map(&:strip) if note_split.size > 1

        definitions
      end

      def extract_terms
        [
          extract_primary_designation,
          *extract_synonymous_designations,
          extract_international_symbol_designation,
        ].compact
      end

      def extract_primary_designation
        raw_term = find_value_for("TERM")
        raw_term = "NA" if raw_term == "....."

        term = mathml_to_asciimath(parse_anchor_tag(raw_term))

        Iev::Termbase::NestedTermBuilder.build(
          type: "expression",
          term: term,
          data: find_value_for("TERMATTRIBUTE"),
          status: "Preferred",
        )
      end

      def extract_synonymous_designations
        retval = (1..3).map do |num|
          designations = find_value_for("SYNONYM#{num}") || ""

          # Some synonyms have more than one entry
          designations.split(/<[pbr]+>/).map do |raw_term|
            term = mathml_to_asciimath(parse_anchor_tag(raw_term))

            Iev::Termbase::NestedTermBuilder.build(
              type: "expression",
              term: term,
              data: find_value_for("SYNONYM#{num}ATTRIBUTE"),
              status: find_value_for("SYNONYM#{num}STATUS"),
            )
          end
        end

        retval.flatten.compact
      end

      def extract_international_symbol_designation
        term = mathml_to_asciimath(parse_anchor_tag(find_value_for("SYMBOLE")))

        Iev::Termbase::NestedTermBuilder.build(
          type: "symbol",
          international: true,
          term: term,
        )
      end

      def text_to_asciimath(text)
        html_entities_to_asciimath(text.decode_html)
      end

      def html_to_asciimath(input)
        return input if input.nil? || input.empty?

        to_asciimath = Nokogiri::HTML.fragment(input, "UTF-8")

        to_asciimath.css('i').each do |math_element|
          # puts "HTML MATH!!  #{math_element.to_xml}"
          # puts "HTML MATH!!  #{math_element.text}"
          decoded = text_to_asciimath(math_element.text)
          case decoded.length
          when 1..12
            # puts "(#{math_element.text} to => #{decoded})"
            math_element.replace "stem:[#{decoded}]"
          when 0
            math_element.remove
          else
            math_element.replace "_#{decoded}_"
          end
        end

        to_asciimath.css('sub').each do |math_element|
          case math_element.text.length
          when 0
            math_element.remove
          else
            math_element.replace "~#{text_to_asciimath(math_element.text)}~"
          end
        end

        to_asciimath.css('sup').each do |math_element|
          case math_element.text.length
          when 0
            math_element.remove
          else
            math_element.replace "^#{text_to_asciimath(math_element.text)}^"
          end
        end

        to_asciimath.css('ol').each do |element|
          element.css('li').each do |li|
            li.replace ". #{li.text}"
          end
        end

        to_asciimath.css('ul').each do |element|
          element.css('li').each do |li|
            li.replace "* #{li.text}"
          end
        end

        # Replace sans-serif font with monospace
        to_asciimath.css('font[style*="sans-serif"]').each do |x|
          x.replace "`#{x.text}`"
        end

        html_entities_to_stem(
          to_asciimath.children.to_s.gsub(/\]stem:\[/, '').gsub(/<\/?[uo]l>/, '')
        )
      end

      def html_entities_to_asciimath(x)
        x.gsub("&alpha;", "alpha").
          gsub("&beta;", "beta").
          gsub("&gamma;", "gamma").
          gsub("&Gamma;", "Gamma").
          gsub("&delta;", "delta").
          gsub("&Delta;", "Delta").
          gsub("&epsilon;", "epsilon").
          gsub("&varepsilon;", "varepsilon").
          gsub("&zeta;", "zeta").
          gsub("&eta;", "eta").
          gsub("&theta;", "theta").
          gsub("&Theta;", "Theta").
          gsub("&vartheta;", "vartheta").
          gsub("&iota;", "iota").
          gsub("&kappa;", "kappa").
          gsub("&lambda;", "lambda").
          gsub("&Lambda;", "Lambda").
          gsub("&mu;", "mu").
          gsub("&nu;", "nu").
          gsub("&xi;", "xi").
          gsub("&Xi;", "Xi").
          gsub("&pi;", "pi").
          gsub("&Pi;", "Pi").
          gsub("&rho;", "rho").
          gsub("&beta;", "beta").
          gsub("&sigma;", "sigma").
          gsub("&Sigma;", "Sigma").
          gsub("&tau;", "tau").
          gsub("&upsilon;", "upsilon").
          gsub("&phi;", "phi").
          gsub("&Phi;", "Phi").
          gsub("&varphi;", "varphi").
          gsub("&chi;", "chi").
          gsub("&psi;", "psi").
          gsub("&Psi;", "Psi").
          gsub("&omega;", "omega")
      end

      def html_entities_to_stem(x)
        x.gsub("&alpha;", "stem:[alpha]").
          gsub("&beta;", "stem:[beta]").
          gsub("&gamma;", "stem:[gamma]").
          gsub("&Gamma;", "stem:[Gamma]").
          gsub("&delta;", "stem:[delta]").
          gsub("&Delta;", "stem:[Delta]").
          gsub("&epsilon;", "stem:[epsilon]").
          gsub("&varepsilon;", "stem:[varepsilon]").
          gsub("&zeta;", "stem:[zeta]").
          gsub("&eta;", "stem:[eta]").
          gsub("&theta;", "stem:[theta]").
          gsub("&Theta;", "stem:[Theta]").
          gsub("&vartheta;", "stem:[vartheta]").
          gsub("&iota;", "stem:[iota]").
          gsub("&kappa;", "stem:[kappa]").
          gsub("&lambda;", "stem:[lambda]").
          gsub("&Lambda;", "stem:[Lambda]").
          gsub("&mu;", "stem:[mu]").
          gsub("&nu;", "stem:[nu]").
          gsub("&xi;", "stem:[xi]").
          gsub("&Xi;", "stem:[Xi]").
          gsub("&pi;", "stem:[pi]").
          gsub("&Pi;", "stem:[Pi]").
          gsub("&rho;", "stem:[rho]").
          gsub("&beta;", "stem:[beta]").
          gsub("&sigma;", "stem:[sigma]").
          gsub("&Sigma;", "stem:[Sigma]").
          gsub("&tau;", "stem:[tau]").
          gsub("&upsilon;", "stem:[upsilon]").
          gsub("&phi;", "stem:[phi]").
          gsub("&Phi;", "stem:[Phi]").
          gsub("&varphi;", "stem:[varphi]").
          gsub("&chi;", "stem:[chi]").
          gsub("&psi;", "stem:[psi]").
          gsub("&Psi;", "stem:[Psi]").
          gsub("&omega;", "stem:[omega]")
      end

      def mathml_to_asciimath(input)
        return input if input.nil? || input.empty?

        unless input.match?(/<math>/)
          return html_to_asciimath(input)
        end

        # puts "GOING TO MATHML MATH"
        # puts input
        to_asciimath = Nokogiri::HTML.fragment(input, "UTF-8")
        # to_asciimath.remove_namespaces!

        to_asciimath.css('math').each do |math_element|
          asciimath = MathML2AsciiMath.m2a(text_to_asciimath(math_element.to_xml)).strip
          # puts"ASCIIMATH!!  #{asciimath}"

          if asciimath.empty?
            math_element.remove
          else
            math_element.replace "stem:[#{asciimath}]"
          end
        end

        html_to_asciimath(
          to_asciimath.children.to_s
        )
      end

      def extract_definition_value
        if definition_values[:definition]
          mathml_to_asciimath(definition_values[:definition].strip)
        end
      end

      def extract_authoritative_source
        source_val = find_value_for("SOURCE")
        return nil if source_val.nil?
        SourceParser.new(source_val).parsed_sources
      end

      def extract_superseded_concepts
        replaces_val = find_value_for("REPLACES")
        return nil if replaces_val.nil?
        SupersessionParser.new(replaces_val).supersessions
      end

      SIMG_PATH_REGEX = "<simg .*\\/\\$file\\/([\\d\\-\\w\.]+)>"
      FIGURE_ONE_REGEX = "<p><b>\\s*Figure\\s+(\\d)\\s+[–-]\\s+(.+)\\s*<\\/b>(<\\/p>)?"
      FIGURE_TWO_REGEX = "#{FIGURE_ONE_REGEX}\\s*#{FIGURE_ONE_REGEX}"
      def parse_anchor_tag(text)
        if text
          part_number = find_value_for("IEVREF").slice(0,3)

          # Convert IEV term references
          # Convert href links
          # Need to take care of this pattern: `inverse de la <a href="IEV103-06-01">période<a>`
          text.
            gsub(/<a href="?(IEV)\s*(\d\d\d-\d\d-\d\d)"?>(.*?)<\/?a>/, '{{\3, \1:\2}}').
            gsub(/<a href="?\s*(\d\d\d-\d\d-\d\d)"?>(.*?)<\/?a>/, '{{\3, IEV:\2}}').
            gsub(/<a href="(.*?)">(.*?)<\/a>/, '\1[\2]').
            gsub(Regexp.new([SIMG_PATH_REGEX, "\\s*", FIGURE_TWO_REGEX].join('')), "image::/assets/images/parts/#{part_number}/\\1[Figure \\2 - \\3; \\6]").
            gsub(Regexp.new([SIMG_PATH_REGEX, "\\s*", FIGURE_ONE_REGEX].join('')), "image::/assets/images/parts/#{part_number}/\\1[Figure \\2 - \\3]").
            gsub(/<img\s+(.+?)\s*>/, "image::/assets/images/parts/#{part_number}/\\1[]").
            gsub(/<br>/, "\n").
            gsub(/<b>(.*?)<\/b>/, "*\\1*")

        end
      end
    end
  end
end
