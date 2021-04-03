#!/usr/bin/env ruby

# file: noticesys.rb

require 'down'        # file downloader
require 'ogextractor' # extract metadata


module NoticeSys

  class Client

    def initialize(user='', rmagick=nil, debug: false)
      @user, @rmagick, @debug = user, rmagick, debug
    end

    # params expected:  msg, file1, file2, file3
    #
    def send_input(params={})

      # save the file attachments containing the images etc.

      files = (1..3).map do |n| 
      
        f = params['file' + n.to_s]
        next unless f        
        
        original = f[:tempfile].to_path
        
        scale_img original
        
      end.compact    
              
      msg = params['msg']

      urls = msg.scan(/https:\/\/[^ ]+/)
      
      if urls.any? then

        h2 = OgExtractor.new(urls.last).to_h
        
        puts 'h2: ' + h2.inspect if @debug
        
        if h2 then
          h = {msg: msg, files: files}   

          h[:site]= h2[:url][/https?:\/\/([^\/]+)/,1].sub(/^www\./,'')

          if h2[:img] then
            tmpfile = Down.download h2[:img]
            files2 = scale_img tmpfile.to_path
          end
          
          h[:files] = files2 || []
          h[:card] = {h2[:card] => { title: h2[:title], desc: h2[:desc], 
                                     url: h2[:url]}}
          h[:msg] = msg.sub(urls.last,'')

          return "notice/%s/json: %s" % [@user, h.to_json]
          
        end
              
      end    

      return "notice/%s: %s" % [@user, msg]      

    end 
    
    private

    def scale_img(raworiginal)    

      original = if raworiginal =~ /\.\w+$/ then
      
        raworiginal
        
      else
      
        neworiginal = raworiginal + '.jpg'
        FileUtils.mv raworiginal, neworiginal
        neworiginal
        
      end
      
      res = %w(240x240 360x360 *518x389 1280x720 2048x1080)        
      a = @rmagick.resize(original, res)
      a2 = (a  + [nil,nil,nil]).take(res.length)

      oldfile = nil
      sizes = %w(240x240 360x360 small medium large)
      
      file_sizes = a2.zip(sizes).map.with_index do |x, i|

        f, label = x

        if f then        
          
          f2 = f.sub(/_(n\d+x\d+)\.\w+$/) {|x| x.sub($1, label)}

          FileUtils.mv f, f2
          oldfile = f2  

        elsif oldfile

          f2 = oldfile.sub(/_(\w+)\.\w+$/) {|x| x.sub($1, label)}

          oldfile = original if i == a.length - 1

          FileUtils.cp oldfile, f2

        end
                  
        
        f2

      end      
                      
      imgfile = original.sub(/\.\w+$/,'2\0')
      FileUtils.mv original, imgfile

      file_sizes << imgfile

    end

  end 

end 
