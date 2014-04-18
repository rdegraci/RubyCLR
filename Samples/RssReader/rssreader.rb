require 'winforms'

reference 'System'
reference_file 'UserInterface\bin\debug\UserInterface.exe'

include System::Collections
include System::Drawing::Drawing2D
include System::IO
include System::Net

class RssItem
  include RubyClr::Bindable

  def get_binding_context
    self.members
  end

  attr_reader :attributes
  attr_writer :attributes

  def members
    ['title', 'link', 'description']
  end

  def title
    @attributes['title']
  end

  def link
    @attributes['link']
  end

  def description
    @attributes['description']
  end

  def url
    @attributes['url']
  end
end

class RssFeed < RssItem
  attr_reader :items

  def image
    @image == nil ? nil : @image.url
  end
  
  def read_item(r, name)
    end_found = false
    item = RssItem.new
    while !end_found and r.Read
      if r.NodeType == XmlNodeType::EndElement and r.LocalName.downcase == name
        end_found = true
      elsif r.NodeType == XmlNodeType::Element
        item.attributes ||= {}
        item.attributes[r.LocalName] = r.ReadString
      end
    end
    item
  end    

  def initialize(path)
    auto_close(XmlTextReader.new(path)) do |r|
      @items = []
      found_channel = false
      while r.read
        local_name = r.LocalName.downcase
        if r.node_type == XmlNodeType::Element
          if !found_channel
            found_channel = true if local_name == 'channel'
          elsif local_name == 'item'
            @items << read_item(r, 'item')
          elsif local_name == 'image'
            @image = read_item(r, 'image')
          else
            if r.MoveToContent == XmlNodeType::Element
              content = r.ReadString
              if r.NodeType == XmlNodeType::EndElement
                @attributes ||= {}
                @attributes[r.LocalName] = content
              end
            end
          end
        end
      end
    end
  end
end

RssFeedUrl = Struct.new(:name, :link)

class RssLinks
  def self.load(path)
    a = []
    auto_dispose(StreamReader.new(FileStream.new(path, FileMode::Open))) do |r|
      a << RssFeedUrl.new(*r.ReadLine.split(',')) until r.EndOfStream
    end
    a
  end
end

class BrowserView < ShadowControl
  attr_reader :form

  def initialize(url)
    @form = layout(UserInterface::Browser.new) do |form|
      form.Size = Size.new(800, 800)
      form.browserControl.url = Uri.new(url)
      form.browserControl.navigated do |sender, args|
        form.text = form.browserControl.document_title
      end
    end
    #
    #form      = Form.new
    #form.Size = Size.new(800, 800)
    #form.Text = 'Browser view!'
    #
    #browser      = WebBrowser.new
    #browser.Dock = DockStyle::Fill
    #browser.Url  = Uri.new(url)
    #browser.Navigated do |sender, args|
    #  # when ToString is missing the error message is bizarre - really need to
    #  # clean up error messages form.Text = browser.Url.ToString
    #  form.Text = browser.DocumentTitle
    #end
    #
    #form.Controls.Add(browser)
    #@form = form
  end
end

class RssView < ShadowControl
  attr_reader :control

  def bind_to(data_source)
    @data_source = data_source
    @control.grid.data_source = data_source
  end

  def title=(feed_title)
    @control.headerStrip.items[0].text = feed_title
  end

  def image=(image_url)
    if image_url != nil
      @control.imagePanel.controls[0].image = Bitmap.new(WebRequest.Create(image_url).GetResponse.GetResponseStream) if image_url != nil
    else
      @control.imagePanel.Visible = false
    end
  end

  def initialize_header_strip(header_strip)
    header_renderer = ToolStripProfessionalRenderer.new
    header_renderer.RenderToolStripBackground do |sender, args|
      start_color = Color.White
      end_color   = Color.FromArgb(168, 186, 212)
      lines       = 6

      bounds_height = args.AffectedBounds.Height
      bounds_width  = args.AffectedBounds.Width
      height        = (bounds_height + lines - 1) / lines
      stripe_height = height - 1
      
      auto_dispose(LinearGradientBrush.new(Rectangle.new(0, 0, bounds_width, stripe_height),
                                           start_color, end_color, LinearGradientMode::Horizontal)) do |b|
        0.upto(lines - 1) do |i|
          args.Graphics.FillRectangle(b, Rectangle.new(0, height * i + 1, bounds_width, stripe_height))
        end
      end

      auto_dispose(SolidBrush.new(Color.FromArgb(177, 177, 177))) do |b|
        args.Graphics.FillRectangle(b, Rectangle.new(0, bounds_height - 1, bounds_width, 1))
      end
    end
    header_strip.Renderer = header_renderer
  end

  def initialize_close_item(header_strip)
    close_item = header_strip.items[1]
    close_item.click do |sender, args|
      control.parent.controls.remove(control)
    end
  end
  
  def initialize
    @control = layout(UserInterface::View.new) do |control|
      initialize_header_strip(control.headerStrip)
      initialize_close_item(control.headerStrip)

      control.grid.auto_generate_columns = false
      control.Load do |sender, args|
        control.grid.cell_content_click do |sender, args|
          url = @data_source[args.row_index].link
          BrowserView.new(url).form.show
        end
      end
    end
  end
end

class MainForm
  def initialize_flow_panel(flow_panel)
    flow_panel.resize do |sender, args|
      width = flow_panel.client_size.width - flow_panel.padding.left - flow_panel.padding.right
      if form.client_size.width > 0 and width != @width
        @width = width
        flow_panel.controls.each do |view|
          padding    = view.margin.right + view.margin.left
          view_width = view.minimum_size.width + padding
          half_width = @width / 2

          if half_width > view_width
            view.width = half_width - padding
          else
            view.width = @width - padding
          end
        end
      end
    end
  end

  def initialize_menu_renderer(menu)
    menu_renderer              = ToolStripProfessionalRenderer.new
    menu_renderer.RoundedEdges = false

    menu_renderer.RenderToolStripBackground do |sender, args|
      auto_dispose(SolidBrush.new(Color.FromArgb(91, 91, 91))) do |b|
        args.Graphics.FillRectangle(b, args.Graphics.ClipBounds)
      end
    end

    menu_renderer.RenderMenuItemBackground do |sender, args|
      if args.Item.Selected
        auto_dispose(SolidBrush.new(Color.FromArgb(80, 80, 80))) do |b|
          args.Graphics.FillRectangle(b, args.Graphics.ClipBounds)
        end
      end
    end
    
    menu.renderer   = menu_renderer
    menu.fore_color = Color.White
  end

  def initialize_choose_feed_button(choose_feed_button)
    choose_feed_button.Click do |sender, args|
      MessageBox.show("selected #{@form.feedComboBox.selected_value}")
    end
  end

  def initialize_feed_views(data_source, flow_panel)
    data_source.each do |source|
      feed       = RssFeed.new(source.link)
      view       = RssView.new
      view.title = source.name
      view.image = feed.image

      view.bind_to(feed.items)
      flow_panel.controls.add(view.control)
    end
  end
  
  def initialize
    @data_source = RssLinks.load('.\links.dat')
    @form = layout(UserInterface::MainForm.new) do |form|
      puts 'here' # I am segfaulting without this puts here - need to figure this out!
      initialize_flow_panel(form.flowPanel)
      initialize_menu_renderer(form.menu)
      initialize_choose_feed_button(form.chooseFeedButton)
      initialize_feed_views(@data_source, form.flowPanel)
    end 
    @form.feedComboBox.DataSource = @data_source
  end
end

WinFormsApp.run(MainForm)
