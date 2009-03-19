require 'rubygems'

gem 'main', '>= 2.8.2'
gem 'highline', '>= 1.4.0'

require 'main'
require 'highline/import'

HighLine.track_eof = false


Main {
  def initialize
    @config_file = File.join(ENV['HOME'], '.seedr')
    @config = {}
    if File.file? @config_file
      @config = YAML.load_file(@config_file)
    end
  end

  def run
    puts "seedr [command] --help for usage instructions."
    puts "The available commands are: \n   add remove change list recent_videos my_videos comment upload multiupload categories"
  end

  mode 'categories' do
    description 'list of categories available on site'
    def run
      current_site = @config[:current]
      account = @config[:accounts][current_site]
      Seedr::Bot.new(current_site) do |b|
        b.login(account[:username], account[:password])
        c = b.categories
        if c.length > 0
          say "ID\tName"
          c.sort.each {|k, v| say "#{k}\t#{v}"}
        else
          say "There are no any categories on site."
        end
      end
    end
  end

  mode 'my_videos' do
    description 'show my videos'
    def run
      current_site = @config[:current]
      account = @config[:accounts][current_site]
      Seedr::Bot.new(current_site) do |b|
        b.login(account[:username], account[:password])
        b.get_my_videos.each {|v| puts v}
      end
    end
  end

  mode 'recent_videos' do
    description 'show recent videos'
    def run
      current_site = @config[:current]
      account = @config[:accounts][current_site]
      Seedr::Bot.new(current_site) do |b|
        b.login(account[:username], account[:password])
        b.get_recent_videos.each {|v| puts v}
      end
    end
  end

  mode 'comment' do
    description 'comment on video'
    argument('video', 'v') {
      argument :optional
      description 'optional video id on site'
    }
    option('message', 'm') {
      argument :optional
      description 'optional message'
    }

    def run
      if params['video'].given?
        video_id = params['video'].value
      else
        video_id = ask('Video ID: ')
      end

      if params['message'].given?
        message = params['message'].value
      else
        message = ask('Message: ')
      end

      current_site = @config[:current]
      account = @config[:accounts][current_site]
      Seedr::Bot.new(current_site) do |b|
        b.login(account[:username], account[:password])
        b.comment(video_id, message)
      end

      say 'Video has been commented.'
    end
  end

  mode 'upload' do
    description 'upload file to site'
    def run
      say 'Uploaded successfuly'
    end
  end

  mode 'multiupload' do
    description 'upload file to all known sites'
    def run
      say 'Uploaded successfuly'
    end
  end

  mode 'add' do
    description 'Adds a new account for site. Prompts for site, username and password.'
    argument('site', 's') {
      validate {|s| s.match /\A[^.]+\.(com|ru)\Z/}
      description 'site'
    }
    option('username', 'u') {
      argument :optional
      description 'optional user'
    }
    option('password', 'p') {
      argument :optional
      description 'optional password'
    }

    def run
      account = Hash.new
      site = params[:site].value
      say "Add new account:"
    
      if params['username'].given?
        account[:username] = params['username'].value
      else
        account[:username] = ask('Username: ') do |q|
          q.validate = /\S+/
        end
      end

      if params['password'].given?
        account[:password] = params['password'].value
      else
        account[:password] = ask("Password (won't be displayed): ") do |q|
          q.echo = false
          q.validate = /\S+/
        end
      end

      @config[:accounts] = Hash.new if @config[:accounts].nil?
      @config[:accounts][site] = account
      @config[:current] = site
      File.open(@config_file, 'w') do |f|
        YAML.dump(@config, f)
      end
      say "Account added."
    end
  end

  mode 'remove' do
    description 'Removes an account for site.'
    argument('site') { 
      optional
      description 'site which account you would like to remove' 
    }
    
    def run
      if params['site'].given?
        site = params['site'].value
      else
        site = ask 'Site which account you want to remove: ' do |q|
          q.validate = /\A[^.]+\.(com|ru)\Z/
        end
      end
      
      @config[:accounts].delete(site)

      File.open(@config_file, 'w') do |f|
        YAML.dump(@config, f)
      end

      say "Account removed."
    end
  end
  
  mode 'list' do
    description 'Lists all the accounts that have been added and puts a * by the current one.'
    def run
      @config[:accounts].each {|k, v| say "#{@config[:current]==k ? '*': ''}#{k}\t#{v[:username]}"}
    end
  end
  
  mode 'change' do
    description 'Changes the current account being used for uploading etc. to the site provided. If no username is provided, a list is presented and you can choose from there.'
    argument( 'site' ) { 
      optional
      description 'site you would like to switched to' 
    }
    
    def run
      if params['site'].given?
        new_current = params['site'].value
      else
        @config.each do |site, a|
          say "#{site}\t#{a[:username]}"
        end
        new_current = ask 'Change current account to: '
      end

      @config[:current] = new_current
      File.open(@config_file, 'w') do |f|
        YAML.dump(@config, f)
      end
      say "#{new_current} is now the current account.\n"
    end
  end
  
}

