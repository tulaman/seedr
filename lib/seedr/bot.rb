module Seedr
  class Bot
    attr_reader :username, :password
  
    def initialize(site)
      @site = site
      @actor = "seedr/#{site}/bot".to_const.new
      yield(self) if block_given?
    end
 
    def authorized?
      @is_logged_in
    end 

    def login(username, password)
      @username = username
      @password = password
      @is_logged_in = true
      @actor.login(username, password)
    end
  
    def logout
      @is_logged_in = false
      @actor.logout
    end
  
    def get_recent_videos(count = 10)
      @actor.get_recent_videos(count)
    end

    def get_my_videos(count = 10)
      raise UnauthorizedError unless authorized?
      @actor.get_my_videos(count)
    end

    def categories
      @actor.categories
    end
    
    def comment(v, message = 'Cool!')
      raise UnauthorizedError unless authorized?
      @actor.comment(v, message)
    end
  
    def upload(filename, meta)
      raise UnauthorizedError unless authorized?
      @actor.upload(filename, meta)
    end

    def check_status(video_or_id)
      @actor.check_status(video_or_id)
    end
  end
end
