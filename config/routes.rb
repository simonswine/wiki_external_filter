Rails.application.routes.draw do #|map|
match 'wiki_external_filter/:filename', :controller => 'wiki_external_filter', :action => 'filter', :macro => 'video', :index => '1', :requirements => { :filename => /video\.flv/ }

match 'wiki_external_filter/:filename', :controller => 'wiki_external_filter', :action => 'filter', :macro => 'video_url', :index => '1', :requirements => { :filename => /video_url\.flv/ }
end
