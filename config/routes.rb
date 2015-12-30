if Rails::VERSION::MAJOR >= 3
  Rails.application.routes.draw do 
    match 'wiki_external_filter', :to => 'wiki_external_filter#filter', :via => [:get]
    match 'wiki_external_filter/:filename', :controller => 'wiki_external_filter', :via => [:get], :action => 'filter', :macro => 'video', :index => '1', :requirements => { :filename => /video\.flv/ }

    match 'wiki_external_filter/:filename', :controller => 'wiki_external_filter', :via => [:get], :action => 'filter', :macro => 'video_url', :index => '1', :requirements => { :filename => /video_url\.flv/ }
  end
else
  ActionController::Routing::Routes.draw do |map|
    map.connect 'wiki_external_filter/:filename', :controller => 'wiki_external_filter', :action => 'filter', :macro => 'video', :index => '1', :requirements => { :filename => /video\.flv/ }
    map.connect 'wiki_external_filter/:filename',  :controller => 'wiki_external_filter', :action => 'filter', :macro => 'video_url', :index => '1', :requirements => { :filename => /video_url\.flv/ }
  end
end
