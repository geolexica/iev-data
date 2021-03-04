# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

module IEV::Termbase
  class Concept < Hash
    include CLI::UI

    attr_accessor :id
    attr_accessor :terms
    DEFAULT_LANGUAGE = "eng"

    def initialize(options={})
      terms = options.delete(:terms) || []
      terms.each do |term|
        add_term(term)
      end

      options.each_pair do |k,v|
        self.send("#{k}=", v)
      end
    end

    def add_term(term)
      self[term.language_code] = term
    end

    def default_term
      if self[DEFAULT_LANGUAGE]
        self[DEFAULT_LANGUAGE]
      else
        set_ui_tag id
        warn "Concept is missing an English term and probably needs updating."
        self[keys.first]
      end
    end

    def to_hash
      default_hash = {
        "termid" => id,
        "term" => default_term.terms.first["designation"],
        "related" => default_term.related_concepts,
      }

      default_hash.compact!

      self.inject(default_hash) do |acc, (lang, term)|
        acc.merge!(lang => term.to_hash)
      end
    end

    def to_file(filename)
      File.open(filename,"w") do |file|
        file.write(to_hash.to_yaml)
      end
    end

  end
end
