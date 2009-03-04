class NotAuthorizedError < StandardError ; end
class NetError < StandardError ; end
class UploadFailure < StandardError ; end

module Seedr
  module RutubeRu
    class Video < Seedr::Video ; end

    CATEGORIES = {
      "Юмор, развлечения" => 19,
      "Кино, ТВ, телешоу" => 5,
      "Аварии, катастрофы, драки" => 1,
      "Музыка, выступления" => 6,
      "Мультфильмы" => 7,
      "Спорт" => 16,
      "Технологии, наука" => 17,
      "Авто, мото" => 2,
      "Рекламные ролики" => 14,
      "Природа, животные" => 10,
      "Игры" => 22,
      "Новости, политика" => 8,
      "Друзья, вечеринки" => 3,
      "Искусство, творчество" => 4,
      "Видеооткрытки, видеоблоги" => 20,
      "Семья, дом, дети" => 15,
      "Праздники, торжества" => 9,
      "Путешествия, страны, города" => 11,
      "Эротика" => 18,
      "Разное" => 13,
    }

    class Bot
      LOGIN_URL = 'http://rutube.ru/login.html'
      LOGOUT_URL = 'http://rutube.ru/logout.html'
      LAST_VIDEO_URL = 'http://rutube.ru/cgi-bin/xmlapi.cgi?rt_sort_by=date&rt_count=%d&rt_mode=movies'
      MY_VIDEO_URL = 'http://%s.rutube.ru/movies?view=compact&oby=recent_tracks'
      COMMENT_URL = 'http://rutube.ru/tracks/comments.html'
      UPLOAD_URL = 'http://uploader.rutube.ru/upload2.html/%s'

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

      # TODO: use Nokogiri::XML here
      def get_recent_videos(count = 10)
        videos = Array.new
        http_get(URI.parse(LAST_VIDEO_URL % count)) do |doc|
          d = REXML::Document.new(doc)
          d.root.each_element('movie') do |movie|
            id = movie.attributes['id']
            title = movie.get_elements('title').first.text.strip
            description = movie.get_elements('description').first.text
            videos << Video.new(id, title, description)
          end
        end
        videos
      end

      def logout
        url = URI.parse(LOGOUT_URL)
        res = Net::HTTP.start(url.host, url.port) do |http|
          http.get(url.path, {'Cookie' => @auth_cookie})
        end
        raise NetError unless res.class == Net::HTTPFound
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
        videos = Array.new
        http_get(URI.parse(MY_VIDEO_URL % @username)) do |doc|
          d = Nokogiri::HTML(doc)
          d.xpath('//div[@class="track"]/div[@class="col1"]/div/a[@class="trackTitle"]').each do |a|
            id = a['href'].match(/\/(\d+)\.html/)[1]
            title = a.text
            description = a['title']
            videos << Video.new(id, title, description)
          end
        end
        videos[0..count-1]
      end

      def comment(video, comment = 'Cool!')
        url = URI.parse(COMMENT_URL)
        res = Net::HTTP.start(url.host, url.port) do |http|
          req = Net::HTTP::Post.new(url.path, {'Cookie' => @auth_cookie})
          req.form_data = {
            :page      => 0, 
            :parent_id => 0, 
            :post_id   => video.id, 
            :type      => 'track', 
            :rm        => 'add_ajax',
            :text      => comment
          }
          http.request(req)
        end
        res
      end

      private

      def http_get(url)
        res = Net::HTTP.start(url.host, url.port) do |http|
          http.get(url.request_uri, {'Cookie' => @auth_cookie})
        end
        case res
        when Net::HTTPOK
          yield(res.body)
        else
          raise NetError
        end
      end
    end
  end
end
