require File.dirname(__FILE__) + '/../../lib/params_parser_with_ignore.rb'

D2d::Application.config.middleware.swap ActionDispatch::ParamsParser, MyApp::ParamsParser, :ignore_prefix => '/'