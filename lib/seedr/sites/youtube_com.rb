module Seedr
  module YoutubeCom
    class Video < Seedr::Video
      attr_accessor :comments_feed, :state
      def initialize(id, title, desc, comments_feed, state = :published)
        super(id, title, desc)
        @comments_feed = comments_feed
        @state = state
      end

      def published?
        state == :published
      end

      def to_s
        puts '-' * 10
        puts "ID: #{id}"
        puts "Title: #{title}"
        puts "Description: #{desc}"
        puts "Comments feed: #{comments_feed}"
        puts '-' * 10
      end
    end

    class Bot
      LOGIN_URL = 'https://www.google.com/youtube/accounts/ClientLogin'
      MY_VIDEO_URL = 'http://gdata.youtube.com/feeds/api/users/default/uploads'
      LAST_VIDEO_URL = 'http://gdata.youtube.com/feeds/api/standardfeeds/most_recent'
      UPLOAD_URL = 'http://uploads.gdata.youtube.com/feeds/api/users/%s/uploads'
     
      @@client_id = 'ytapi-IlyaLityuga-Seedr-vub73lnj-0'
      @@dev_key = 'AI39si6KB7Ycx4Hg0IISJaxF7rpiMo7zWRkdF7nYml3ftDI9YJBDoGiLI0X6nv_CYQgPA9DvbxtnO7cOBYCpKsuNNhvHAt8HQA'

      def self.client_id=(client_id)
        @@client_id = client_id
      end

      def self.developer_key=(dev_key)
        @@dev_key = dev_key
      end

      def login(username, password)
        @username = username
        @password = password
        # generate request
        uri = URI.parse(LOGIN_URL)
        req = Net::HTTP::Post.new(uri.path)
        req.form_data = {
          :Email   => username, 
          :Passwd  => password, 
          :service => 'youtube', 
          :source  => 'TestLogin'
        }
        
        # prepare transport
        http = Net::HTTP.new(uri.host, uri.port) 
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        
        # start session
        response = http.start {|h| h.request(req)}
        
        # show result
        @auth = response.body.split.first.split('=').last
      end

      def get_my_videos(count = 10)
        get_videos(MY_VIDEO_URL, count)
      end

      def check_status(video_or_id)
        if video_or_id.class == Seedr::YoutubeCom::Video
          id = video_or_id.id
        end
        get_videos(MY_VIDEO_URL, 100).select {|v| v.id == id}.state
      end

      def get_recent_videos(count = 10)
        get_videos(LAST_VIDEO_URL, count)
      end
      
      def comment(video_id, message = 'Cool!')
        # prepare comment
        data = REXML::Document.new
        data << REXML::XMLDecl.new('1.0', 'UTF-8')
        data.add_element 'entry', {
          'xmlns' => "http://www.w3.org/2005/Atom", 
          'xmlns:yt' => "http://gdata.youtube.com/schemas/2007"
        }
        data.root.add_element REXML::Element.new('content').add_text(message)

        # post it
        uri = URI.parse(video.comments_feed)
        http = Net::HTTP.new(uri.host, uri.port)
        headers = {
          'Content-Type'   => 'application/atom+xml',
          'Authorization'  => "GoogleLogin auth=#{@auth}",
          'X-GData-Client' => @@client_id,
          'X-GData-Key'    => "key=#{@@dev_key}",
        }
        response = http.request_post(uri.path, data.to_s, headers)
      end
      
      def upload(filename, meta = {})
        file = File.new(filename)
        info = {
          :title => 'Unnamed', 
          :description => '', 
          :category => 'Entertainment', 
          :keywords => ''
        }.merge(meta)
        
        # generate XML request
        media_group = REXML::Element.new('media:group')
        media_group.add_element('media:title', {'type' => 'plain'}).add_text(info[:title])
        media_group.add_element('media:description', {'type' => 'plain'}).add_text(info[:description])
        media_group.add_element('media:category', {'scheme' => 'http://gdata.youtube.com/schemas/2007/categories.cat'}).add_text(info[:category])
        media_group.add_element('media:keywords').add_text(info[:keywords])

        api_xml_request = REXML::Document.new << REXML::XMLDecl.new('1.0', 'UTF-8')
        api_xml_request.
          add_element('entry', {
            'xmlns' => 'http://www.w3.org/2005/Atom',
            'xmlns:media' => 'http://search.yahoo.com/mrss/',
            'xmlns:yt' => 'http://gdata.youtube.com/schemas/2007'}).
          add_element(media_group)

        # prepare POST body etc
        uri = URI.parse(UPLOAD_URL % @username)
        boundary = 'f93dcbA3'
        headers = {
          'Content-Type'   => "multipart/related; boundary=#{boundary}",
          'Authorization'  => "GoogleLogin auth=#{@auth}",
          'X-GData-Client' => @@client_id,
          'X-GData-Key'    => "key=#{@@dev_key}",
          'Slug'           => filename,
        }
        body = ''
        body << 
          "--#{boundary}\r\n" <<
          "Content-Type: application/atom+xml; charset=UTF-8\r\n\r\n" <<
          "#{api_xml_request.to_s}\r\n" <<
          "--#{boundary}\r\n" <<
          "Content-Type: application/octet-stream\r\n" <<
          "Content-Transfer-Encoding: binary\r\n\r\n" <<
          file.binmode.read <<
          "\r\n" <<
          "--#{boundary}--\r\n"
 
        # send HTTP request
        response = Net::HTTP.start(uri.host, uri.port) do |http|
          http.request_post(uri.path, body, headers)
        end

        # parse response
        case response
        when Net::HTTPOK, Net::HTTPCreated, Net::HTTPAccepted
          doc = REXML::Document.new(response.body)
          entry = doc.root
          id = entry.get_elements('id').first.text
          title = entry.get_elements('media:group/media:title').first.text
          description = entry.get_elements('media:group/media:description').first.text
          cfeed = entry.get_elements('gd:comments/gd:feedLink').first.attributes["href"]
          return Seedr::YoutubeCom::Video.new(id, title, description, cfeed, :processing)
        else
          raise UploadFailure
        end
      end

      def logout
        puts "Logged out"
      end

      private

      def get_videos(channel_url, count)
        uri = URI.parse(channel_url)
        response = Net::HTTP.start(uri.host, uri.port) do |http|
          query = "#{uri.path}?start-index=1&max-results=#{count}"
          http.get(query, {'Authorization' => "GoogleLogin auth=#{@auth}", 
                           'X-GData-Key' => "key=#{@@dev_key}"})
        end

        videos = Array.new()
        doc = REXML::Document.new(response.body)
#        puts response.body
        doc.each_element('feed/entry') do |entry|
          id = entry.get_elements('id').first.text
          title = entry.get_elements('media:group/media:title').first.text
          description = entry.get_elements('media:group/media:description').first.text
          cfeed = entry.get_elements('gd:comments/gd:feedLink').first.attributes["href"]
          status = :published
#          if (control = entry.get_elements('app:control')) && control.first.get_elements('app:draft').first.text == 'yes'
#            status = control.get_elements('yt:state').first.attributes['name'].to_sym
#          end
          videos << Seedr::YoutubeCom::Video.new(id, title, description, cfeed)
        end
        videos
      end
    end # class
  end # module Bots
end # module Seedr


