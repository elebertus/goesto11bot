require 'redis'
require 'yaml'
require 'twitter'

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
        key = nil

        loop do
          key = @db.randomkey
          score = @db.get key

          if score.to_i >= 0
            break
          end
        end

        self.class.last_loud = key
      end

      def bump
        @db.incr self.class.last_loud
      end

      def sage
        @db.decr self.class.last_loud
      end

      def search(pattern)
        ary = @db.keys(pattern)
        self.class.last_loud = ary[-1]
        return ary
      end

      def score
        return "#{self.class.last_loud}: #{@db.get(self.class.last_loud)}"
      end
      
      def twit_last
        return "#{self.class.last_loud}"
      end
    end

    class TWIT
      include Cinch::Plugin

      def initialize(*args)
        conf = YAML.load_file( 'base.yml' )
        Twitter.configure do |config|
          config.consumer_key = conf["oauth"]["consumer_key"]
          config.consumer_secret = conf["oauth"]["consumer_secret"]
          config.oauth_token = conf["oauth"]["oauth_token"]
          config.oauth_token_secret = conf["oauth"]["oauth_token_secret"]
        end
        @twit = Twitter.new
      end

      def post(text)
        @twit.update(text)
      end

      def get_last
       last = @twit.user_timeline("goesto11bot", :count=> "1")
       "http://twitter.com/#!/goesto11bot/status/" + last.to_s.match(/([0-9]{10,20})/)[0]
      end
    end

   class LISTEN
     include Cinch::Plugin

     def initialize(*args)
       super *args
       @twit = TWIT.new
       @db = REDIS.new
     end

     match %r/(twitlast)/, :use_prefix => true, :use_suffix => false
     react_on :channel

     def execute(m)
       @twit.post("#{@db.twit_last}")
       m.reply "#{@twit.get_last}"
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

    class LOUDSEARCH
      include Cinch::Plugin

      def initialize(*args)
        super *args
        @db = REDIS.new
      end

      match %r!search\s*(\S*)!, :use_prefix => true
      react_on :channel

      def execute(m, query)
        @db.search(query.upcase).last(5).each do |loud|
          m.reply(loud)
        end
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
