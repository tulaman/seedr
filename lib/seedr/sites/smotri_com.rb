module Seedr
  module SmotriCom
    class Video < Seedr::Video
      def self.parse(h)
        new do |v|
          v.id = h['id']
          v.title = h['title']
          v.description = h['description']
          v.rating = h['rating']
          v.votes = h['rateCount']
          v.views = h['viewCount']
          v.comments = h['commentCount']
          v.page_url = "http://smotri.com/video/view/?id=#{v.id}"
        end
      end
    end

    class Bot
      API_URL = 'http://smotri.com/api/json/-/%s/1.0/?lang=rus'

      def login(username, password)
        trust_key = Digest::MD5.hexdigest("#{CONF[:smotri_dev_id]}#{Date.today.to_s}#{CONF[:smotri_dev_pass]}")

        send_command('smotri.auth.get.sid', {'trustKey' => trust_key}) do |res|
          @sid = res['sid']
        end

        send_command('smotri.auth.auth.user', {
          "genAuthTicket" => true,
          "login"         => username,
          "password"      => Digest::MD5.hexdigest(password),
        }) do |res|
          @login = res['user']['login']
          @nick  = res['user']['nick']
          @auth_ticket = res['authTicket']
        end
      end

      def get_recent_videos(count = 10)
        res = send_command('smotri.videos.list.novelty', {
          "maxCount" => count,
          "fetchTotal" => false,
          "noDoubtful" => false,
          "from"       => 0,
        })
        res['videos'].collect {|v| Video.parse v}
      end

      def logout
        true
      end

      def categories
        send_command('smotri.videos.rubric.list', {})['rubrics'].inject({}) {|h, r| h[r['id']] = r['name']; h}
      end

      def upload(filename, meta = {})
        file = File.new(filename)
        info = {
          :title => 'Unnamed', 
          :description => '', 
          :category => '26', 
          :keywords => ''
        }.merge(meta)

        res = send_command('smotri.videos.add', {
          'moneyUp'  => false,
          'rubricId' => info[:category],
          'title'    => info[:title],
          'description' => info[:description],
          'tagsStr'  => info[:keywords]
        })
        upload_url = res['uploadUrl']
        upload_id = res['uploadId']
        url = URI.parse(upload_url)
        post = MultipartPostRequest.create(url, {}, {'upload' => File.open(filename)})
        res = Net::HTTP.start(url.host, url.port) {|http| http.request(post)}
        raise StandardError unless Net::HTTPOK === res

        upload_id
      end

      def get_my_videos(count = 10)
        res = send_command('smotri.videos.list.by.user', {
          "sort"       => 'added',
          "maxCount"   => count,
          "fetchTotal" => false,
          "login"      => @login,
          "from"       => 0,
        })
        res['videos'].collect {|v| Video.parse v}
      end

      def comment(video_id, comment = 'Cool!')
        res = send_command('smotri.comments.add', {'videoId' => video_id, 'text' => comment})
        res['total']
      end

      private

      def send_command(cmd, params)
        url = URI.parse(API_URL % CONF[:smotri_dev_id])
        params['sid'] = @sid if @sid
        cmd_serialized = {
          "method" => cmd,
          "params" => params,
          "id" => nil
        }.to_json

        res = Net::HTTP.start(url.host, url.port) do |http|
          http.request_post(url.request_uri, cmd_serialized)
        end

        raise StandardError unless res.class == Net::HTTPOK
        result = ActiveSupport::JSON.decode(res.body.gsub(/\\u([0-9a-fA-F]{4})/) {[$1.to_i(16)].pack("U*")})
        if result['error']
          puts result['error']['message']
          raise StandardError, result['error']
        end

        return yield(result['result']) if block_given?
        result['result']
      end
    end
  end
end
