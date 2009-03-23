module Seedr
  module YoutubeCom
    class Video < Seedr::Video
      def self.new_from_xml(xml)
        new do |v|
          statistics = xml.get_elements('yt:statistics').first
          votes = xml.get_elements('gd:rating').first
          rating = xml.get_elements('gd:rating').first

          v.id = xml.get_elements('id').first.text.gsub(/^http:\/\/gdata\.youtube\.com\/feeds\/api\/videos\//, '')
          v.title = xml.get_elements('media:group/media:title').first.text
          v.description = xml.get_elements('media:group/media:description').first.text
          v.views = statistics.nil? ? 0 : statistics.attributes['viewCount']
          v.votes = votes.nil? ? 0 : votes.attributes['numRaters']
          v.rating = rating.nil? ? 0 : rating.attributes['average']
          v.comments = xml.get_elements('gd:comments/gd:feedLink').first.attributes['countHint']
        end
      end

      def page_url
        "http://www.youtube.com/watch?v=#{id}"
      end
    end

    class Bot
      LOGIN_URL = 'https://www.google.com/youtube/accounts/ClientLogin'
      MY_VIDEO_URL = 'http://gdata.youtube.com/feeds/api/users/default/uploads'
      LAST_VIDEO_URL = 'http://gdata.youtube.com/feeds/api/standardfeeds/most_recent'
      UPLOAD_URL = 'http://uploads.gdata.youtube.com/feeds/api/users/%s/uploads'
      COMMENTS_URL = 'http://gdata.youtube.com/feeds/api/videos/%s/comments'
      VIDEO_URL = 'http://gdata.youtube.com/feeds/api/videos/%s'
     
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
          :source  => 'Seedr'
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
        uri = URI.parse(COMMENTS_URL % video_id)
        http = Net::HTTP.new(uri.host, uri.port)
        headers = {
          'Content-Type'   => 'application/atom+xml',
          'Authorization'  => "GoogleLogin auth=#{@auth}",
          'X-GData-Client' => CONF[:youtube_client_id],
          'X-GData-Key'    => "key=#{CONF[:youtube_dev_key]}",
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
          'X-GData-Client' => CONF[:youtube_client_id],
          'X-GData-Key'    => "key=#{CONF[:youtube_dev_key]}",
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
          return Seedr::YoutubeCom::Video.new(id, title, description, :processing)
        else
          raise UploadFailure
        end
      end

      def logout
        true
      end

      def categories
        doc = Nokogiri::XML(open('http://gdata.youtube.com/schemas/2007/categories.cat'))
        namespaces = {'app'  => 'http://www.w3.org/2007/app', 
                      'atom' => 'http://www.w3.org/2005/Atom', 
                      'yt'   => 'http://gdata.youtube.com/schemas/2007'}
        doc.xpath('/app:categories/atom:category[yt:assignable]/attribute::term', namespaces).inject({}) do |h, c|
          h[c.to_s] = c.to_s
          h
        end
      end

      def video(video_id)
        Video.new_from_xml REXML::Document.new(open(VIDEO_URL % video_id)).get_elements('/entry').first
      end
      
      private


      def get_videos(channel_url, count)
        channel_url << "?start-index=1&max-results=#{count}"
        doc = open(channel_url, 'Authorization' => "GoogleLogin auth=#{@auth}", 'X-GData-Key' => "key=#{CONF[:youtube_dev_key]}")
        REXML::Document.new(doc).get_elements('feed/entry').collect {|entry| Video.new_from_xml entry}
      end
    end
  end
end


