require 'sqlite3'

module Cinch::Plugins
  module LOUD
    class DATABASE

      LOUDDB = "louds.db"

      INIT_SQL = [
        %q[create table louds (id integer primary key autoincrement, loud varchar not null, rating integer default 1)]
      ]

      def initialize
        do_init_db = !File.exist?(LOUDDB)
        @db = SQLite3::Database.new("louds.db")
        init_db if do_init_db
      end

      def init_db
        INIT_SQL.each { |sql| @db.execute(sql) }
      end

      def add_loud(loud)
        @db.execute("insert into louds (loud) values (?)", loud)
      end
    end

    class BEINGLOUD 
      include Cinch::Plugin
      
      MIN_LENGTH = 10

      def initialize(*args)
        super *args
        @db = DATABASE.new
      end

      match %r/^([A-Z\W]+)$/, :use_prefix => false, :use_suffix => false

      def execute(m, query)
        if query.length >= MIN_LENGTH and query =~ /[A-Z]/ and query.scan(/[A-Z]/).length > query.scan(/\W/).length
          @db.add_loud(query)
        end
      end
    end
  end
end
