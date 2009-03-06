module Seedr
  module YandexRu
    class Video < Seedr::Video ; end
    class Bot
      LOGIN_URL = 'http://passport.yandex.ru/passport?mode=auth'
      LAST_VIDEOS_URL = 'http://video.yandex.ru/recent/rss'
      MY_VIDEOS_URL = 'http://video.yandex.ru/users/%s/rss'
      COMMENT_URL = 'http://video.yandex.ru/actions/ajax/comment-add.xml'
      LOGOUT_URL = 'http://passport.yandex.ru/passport?mode=logout'
      UPLOAD_FORM_URL = 'http://video.yandex.ru/upload/'
      UPLOAD_URL = 'http://up1.video.yandex.ru/q-upload/bv/?upload_token=%s&X-Progress-ID=%s'
      USER_AGENT = 'User-Agent: Mozilla/5.0 (X11; U; Linux i686; ru; rv:1.9.0.6) Gecko/2009020410 Fedora/3.0.6-1.fc9 Firefox/3.0.6'

      def login(username, password)
        @login = username
        url = URI.parse(LOGIN_URL)
        headers = {
          'User-Agent' => USER_AGENT,
          'Content-Type' => 'application/x-www-form-urlencoded',
          'Referer' => 'http://passport.yandex.ru/passport?mode=auth&retpath=http%3A%2F%2Fvideo.yandex.ru'
        }
        data = {
          'retpath'   => 'http://video.yandex.ru',
          'timestamp' => Time.now.to_i,
          'login'     => username,
          'passwd'    => password,
          'twoweeks'  => 'yes',
        }
        res = Net::HTTP.start(url.host, url.port) do |http|
          req = Net::HTTP::Post.new(url.request_uri, headers)
          req.form_data = data
          http.request(req)
        end
        c = res.header['set-cookie'].scan(/([^=]+=[^;]*); path=[^;]+; domain=[^;]+; expires=[^,]+, [^,]+(?:, |$)/i)
        url = URI.parse(res.header['location'])

        res = Net::HTTP.start(url.host, url.port) {|http| http.get(url.request_uri, {'Cookie' => c.join('; ')})}
        c << res.header['set-cookie'].scan(/(yandexuid=[^;]*);/i).first
        url = URI.parse(res.header['location'])

        res = Net::HTTP.start(url.host, url.port) {|http| http.get(url.request_uri, {'Cookie' => c.join('; ')})}
        @cookies = c.join('; ')
        true
      end

      def logout
        open(LOGOUT_URL, {'Cookie' => @cookies})
        true
      end

      def get_recent_videos(count=10)
        RSS::Parser.parse(open(LAST_VIDEOS_URL)).items[0..count].collect do |i|
          Video.new(i.link, i.title, i.description)
        end
      end

      def get_my_videos(count=10)
        RSS::Parser.parse(open(MY_VIDEOS_URL % @login, {'Cookie' => @cookies})).items[0..count].collect do |i|
          Video.new(i.link, i.title, i.description)
        end
      end

      def comment(video_id, comment='Cool!')
        doc = Nokogiri::HTML(open(video_id, {'Cookie' => @cookies}))
        form = doc.xpath('//form[@class="b-form b-form-comment-add"]').first
        fields = form.xpath('input').inject({}) { |h, input| h[input['name']] = input['value']; h}
        fields['body'] = comment
        url = URI.parse(COMMENT_URL)
        res = Net::HTTP.start(url.host, url.port) do |http|
          req = Net::HTTP::Post.new(url.path, {'Cookie' => @cookies})
          req.form_data = fields
          http.request(req)
        end
        raise StandardError unless Net::HTTPOK === res
        return true
      end

      def upload(filename, meta)
        info = {
          :title => 'Безымянный', 
          :description => '', 
          :keywords => ''
        }.merge(meta)

        doc = Nokogiri::HTML(open(UPLOAD_FORM_URL, {'Cookie' => @cookies}))
        form = doc.xpath('//form[@id="upload-noflash"]').first
        upload_token = form.xpath('input[@name="upload-token"]').first['value']

        url = URI.parse(UPLOAD_URL % [upload_token, Digest::MD5.hexdigest(rand(10000).to_s)])
        form_data = {
          'retpath'      => '',
          'upload-token' => upload_token,
          'video'        => File.open(filename),
          'title'        => info[:title],
          'description'  => info[:description],
          'tags'         => info[:keywords],
          'album-id'     => ''
        }
        post = MultipartPostRequest.create(url, {'User-Agent' => USER_AGENT, 'Referer' => 'http://video.yandex.ru/upload/', 'Cookie' => @cookies}, form_data)
        res = Net::HTTP.start(url.host, url.port) do |http|
          http.request(post)
        end
        puts res
        raise StandardError unless Net::HTTPOK === res
        return true
      end

    end
  end
end

