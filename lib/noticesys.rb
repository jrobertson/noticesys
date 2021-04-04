#!/usr/bin/env ruby

# file: noticesys.rb

require 'down'        # file downloader
require 'weblet'      # HTML retrieval
require 'dynarex'     # flat file storage system
require 'unichron'    # universal chron tool (i.e. time calculation)
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
  
  
  class CardView
    
    def initialize(weblet)
      
      @w = weblet
      
    end
    
    def render(dx, rx, card)
      
      card2 = case card.keys.first 
      when :images
      
        card[:images].map.with_index do |img, i|
        
          href = [dx.link.sub(/\/$/,''), rx.topic, 'status', rx.id, 
                  'photo', (i+1).to_s ].join('/')
          url, align = img[:url], img[:align]
          "<a href='%s'><div class='top-crop %s'><img class='img1' src='%s'/></div></a>" % [href, align, url]
          
        end.join
        
      when :summary_large_image

        h2 = card[:summary_large_image]

        rawdesc = h2[:desc]

        desc = rawdesc.length > 147 ? rawdesc[0..147] + '...' : rawdesc
        site = h2[:url][/https?:\/\/([^\/]+)/,1].sub(/^www\./,'')
        title = h2[:title]
        img = h2[:img]
        url = h2[:url]    

        @w.render('card', binding)

      when :summary

        h2 = card[:summary]

        rawdesc = h2[:desc]

        desc = rawdesc.length > 95 ? rawdesc[0..95] + '...' : rawdesc
        site = h2[:url][/https?:\/\/([^\/]+)/,1].sub(/^www\./,'')
        title = h2[:title].length > 46 ? h2[:title][0..46] + '...' :  h2[:title]
        img = h2[:img]
        url = h2[:url]
        
        img_element = if img then 
          "<img src='#{img}'>"
        else
          @w.render('svg/article')
        end

        @w.render('card2', binding)    
      
      end
    end    
  end
  
  class StatusView
    
    def initialize(basepath, xslfile, css_url, weblet_file)
      
      @basepath, @xslfile, @css_url = basepath, xslfile, css_url
      @w = Weblet.new(weblet_file, binding)      
      @card = CardView.new(@w)
      
    end
    
    def render(topic, rawid, referer)      

      id = rawid[0..9].to_i
      
      filepath = File.join(@basepath, topic)
      a = [Time.at(id).strftime("%Y/%b/%-d").downcase, rawid]
      xmlfile = File.join(filepath, "%s/%s/index.xml" % a)
      xslfile = File.join(@basepath, "/xsl/notices/#{topic}.xsl")
      
      unless File.exists? xslfile then
        xslfile = @xslfile
      end

      dx = Dynarex.new(File.join(filepath, 'feed.xml'))
      doc = Rexle.new(File.read(xmlfile))
            
      doc.root.element('summary/title').text = dx.title
      e = doc.root.element('summary/image')

      if e.nil? then
        e = Rexle::Element.new 'image'
        doc.root.element('summary').add e
      end
      
      doc.root.element('summary/image').text = dx.image
      
      # remove the card from the description
      desc = doc.root.element('body/description')
      desc.xpath('img|div').each(&:delete)

      doc   = Nokogiri::XML(doc.root.xml)
      xslt  = Nokogiri::XSLT(File.read(xslfile))

      s = xslt.transform(doc)
      doc = Rexle.new(s.to_s)
     
      rx = Kvx.new(xmlfile)                        

      rawcard = rx.card


      card2, meta = if rawcard and rawcard.length > 10 then
      
        card = JSON.parse(rawcard, symbolize_names: true)
        
        if card.is_a? Hash then      
              
          type = card.keys.first
          h = card[type]
          #img = h[:img].sub(/small(?=\.\w+$)/,'large')
          img = h[:img]
          metadata = @w.render(:meta, binding)
          [@card.render(dx, rx, card), metadata]
          
        end
      else
        '<span/>'
      end
      

      e = doc.root.at_css '#notice'
      desc = e.at_css '#desc'
      desc.add Rexle.new(card2).root      

      ref =  referer
      svg = @w.render 'svg/backarrow', binding
      
      back = if ref then
        "<div id='back'><a href='#{ref}' title='back'>#{svg}</a></div>"
      else
        ''            
      end
      
      @w.render :status, binding

    end
    
  end
  
  class StatusListView
    
    def initialize(basepath, css_url, weblet_file, static_urlbase)
      
      @basepath, @css_url, @static_urlbase = basepath,  css_url, static_urlbase
      @w = Weblet.new(weblet_file, binding)      
      @card = CardView.new(@w)
      
    end
    
    def render(username)      

      s = ''
      
      dx = Dynarex.new(File.join(@basepath, username, 'feed.xml'))
      
      s += @w.render 'user/ptop', binding
      
      notices = dx.all.map do |rx|
      
        card2 = ''
        rawcard = rx.to_h[:card]                
        
        card2 = if rawcard and rawcard.length > 10 then
        
          card = JSON.parse(rawcard, symbolize_names: true)             
          
          if card.is_a? Hash then            
            @card.render(dx, rx, card)
          end
          
        else
          ''
        end      
      
        t2 = Time.at rx.id.to_s[0..9].to_i
        relative_time = Unichron.new(t2).elapsed
        
        d = t2.strftime("%I:%M%p %b %d %Y")
        
        description = if rx.description.length > 1 then
          doc = Rexle.new "<node>%s</node>" % rx.description.gsub(/<\/?p>/,'')                    
          doc.root.xpath('img|div').each(&:delete)
          "<p>%s</p>" % doc.root.xml
        else
          ''
        end

        @w.render :notice, binding
        
      end

      s += notices.join      
      s += @w.render 'user/rsslink', binding                  
      @w.render :user, binding
      
    end
    
  end
    
end 
