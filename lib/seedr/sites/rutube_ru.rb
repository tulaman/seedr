module Seedr
  module RutubeRu
    class Video < Seedr::Video ; end

    class Bot
      LOGIN_URL = 'http://rutube.ru/login.html'
      LOGOUT_URL = 'http://rutube.ru/logout.html'
      LAST_VIDEO_URL = 'http://rutube.ru/cgi-bin/xmlapi.cgi?rt_sort_by=date&rt_count=%d&rt_mode=movies'
      MY_VIDEO_URL = 'http://%s.rutube.ru/movies?view=compact&oby=recent_tracks'
      COMMENT_URL = 'http://rutube.ru/tracks/comments.html'
      UPLOAD_URL = 'http://uploader.rutube.ru/upload2.html/%s'
      CATEGORIES_URL = 'http://rutube.ru/cgi-bin/xmlapi.cgi?rt_mode=categories'

      def login(username, password)
        @username = username
        res = Net::HTTP.post_form(URI.parse(LOGIN_URL), {:nick => username, :pass => password, :rm => 'login', :submit => 'Войти'})
        case res
        when Net::HTTPFound
          @auth_cookie = res.header['set-cookie']
        else
          raise AuthError
        end
      end

      def get_recent_videos(count = 10)
        Nokogiri::XML( open(LAST_VIDEO_URL % count) ).xpath('/response/movie').collect do |movie|
          id = movie.attributes['id']
          title = movie.xpath('title').first.text.strip
          description = movie.xpath('description').first.text
          Video.new(id, title, description)
        end
      end

      def logout
        open(LOGOUT_URL, 'Cookie' => @auth_cookie)
        true
      end

      def categories
        doc = Nokogiri::XML( open(CATEGORIES_URL) )
        doc.xpath('/response/categories/category').inject({}) do |h, cat|
          h[cat.attributes['id'].to_s.to_i] = cat.text
          h
        end
      end

      def upload(filename, meta = {})
        info = {
          :title => 'Unnamed', 
          :description => '', 
          :category => '19', 
          :keywords => ''
        }.merge(meta)

        boundary = Digest::MD5.hexdigest(rand(1000).to_s)
        url = URI.parse(UPLOAD_URL % boundary)
        headers = {'Cookie'   => @auth_cookie}
        ic = Iconv.new('utf8', 'KOI8-r')
        form = {
          'save'      => 'y',
          'xdf'       => boundary,
          'way'       => '1',
          'title'     => ic.iconv(info[:title]),
          'comment'   => ic.iconv(info[:description]),
          'category'  => info[:category],
          'tags'      => ic.iconv(info[:keywords]),
          'comments'  => '0',
          'published' => 'y',
          'winclient' => '1',
          'data'      => File.open(filename)
        }
        post = MultipartPostRequest.create(url, headers, form)
        res = Net::HTTP.start(url.host, url.port) {|http| http.request(post)}
        raise StandardError unless Net::HTTPOK === res

        Video.new(nil, info[:title], info[:description])
      end

      def get_my_videos(count = 10)
        expr = '//div[@class="track"]//a[@class="trackTitle"]'
        v = Nokogiri::HTML(open(MY_VIDEO_URL % @username)).xpath(expr).collect do |a|
          id = a['href'].match(/\/(\d+)\.html/)[1]
          title = a.text
          description = a['title']
          Video.new(id, title, description)
        end
        v[0..count-1]
      end

      def comment(video_id, comment = 'Cool!')
        url = URI.parse(COMMENT_URL)
        res = Net::HTTP.start(url.host, url.port) do |http|
          req = Net::HTTP::Post.new(url.path, {'Cookie' => @auth_cookie})
          req.form_data = {
            :page      => 0, 
            :parent_id => 0, 
            :post_id   => video_id, 
            :type      => 'track', 
            :rm        => 'add_ajax',
            :text      => comment
          }
          http.request(req)
        end
        res
      end
    end
  end
end
