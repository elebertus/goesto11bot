require 'redis'

module Cinch::Plugins
  module LOUD
    class REDIS

      class << self
        attr_accessor :last_loud
      end

      def initialize
        @db = Redis.new(:path => 'redis.sock')
        self.class.last_loud = randomloud
      end

      def add_loud(loud)
        @db.pipelined do
          @db.setnx loud, 1
          @db.persist loud
        end
      end

      def randomloud
        self.class.last_loud = @db.randomkey
      end

      def bump
        @db.incr self.class.last_loud
      end

      def sage
        @db.decr self.class.last_loud
      end

      def score
        return "#{self.class.last_loud}: #{@db.get(self.class.last_loud)}"
      end
    end

    class BEINGLOUD 
      include Cinch::Plugin
      
      MIN_LENGTH = 10

      def initialize(*args)
        super *args
        @db = REDIS.new
      end

      match %r/^([A-Z0-9\W]+)$/, :use_prefix => false, :use_suffix => false

      react_on :channel

      def execute(m, query)
        if query.length >= MIN_LENGTH and 
          query =~ /[A-Z]/ and 
          query.scan(/[A-Z\s0-9]/).length > query.scan(/[^A-Z\s0-9]/).length and
          query !~ /#{Regexp.quote m.bot.nick}/

          @db.add_loud(query)
          m.reply(@db.randomloud)
        end
      end
    end

    class TALKINGTOLOUD
      include Cinch::Plugin
      
      def initialize(*args)
        super *args
        @db = REDIS.new
      end

      prefix lambda { |m| "#{m.bot.nick}" }
      match %r/.*/, :use_prefix => true, :use_suffix => false
      
      def execute(m)
        m.reply(@db.randomloud)
      end
    end

    class LOUDMETA
      include Cinch::Plugin

      def initialize(*args)
        super *args
        @db = REDIS.new
      end

      match %r/(bump|sage|score)$/, :use_prefix => true, :use_suffix => false
      react_on :channel

      def execute(m, query)
        case query
        when 'bump'
          @db.bump
        when 'sage'
          @db.sage
        when 'score'
          m.reply(@db.score)
        end
      end
    end
  end
end
