require 'net/http'

class MultipartPostRequest
  #
  # url = URI.parse('http://test.com/path')
  # post = MultipartPostRequest.create(url, 
  #      { :file => File.open(filename), :filename => filename })
  # res = Net::HTTP.start(url.host, url.port) do |http|
  #   http.request(post)
  # end
  #
  def self.create(uri, headers, pars)
    post = Net::HTTP::Post.new(uri.request_uri, headers)
    boundary = (rand*1000000000).to_i.to_s
    post.set_content_type("multipart/form-data", {:boundary => "#{boundary}"})

    body = ""
    pars.each do |key, value|
      body << "--#{boundary}\r\n"
      append_post_parameter(body, key, value)
    end
    body << "--#{boundary}--"

    post.content_length = body.length
    post.body = body 
    return post
  end

  def self.append_post_parameter(body, key, value)    
    if value.class == File
      body << "Content-disposition: form-data; name=\"#{key}\"; filename=\"#{File.basename(value.path)}\"\r\n"
      body << "Content-type: application/octet-stream\r\n"
      body << "Content-Transfer-Encoding: binary\r\n\r\n"
      body << value.binmode.read
      body << "\r\n"
    else
      body << "Content-disposition: form-data; name=\"#{key}\"\r\n\r\n"
      body << "#{value}\r\n"
    end
  end
end
