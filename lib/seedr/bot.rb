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
  
    def method_missing(method_id, *args)
      if @actor.respond_to?(method_id)
        @actor.send(method_id, *args)
      else
        super
      end
    end
  end
end
