class OptionsController < ApplicationController
#  doorkeeper_for :create
  skip_before_filter :verify_authenticity_token, :only => [:create]
  
#  before_filter :authorize, :only=>[:index]
  active_scaffold :option do |config|
    config.create.refresh_list = true
    config.update.refresh_list = true
    config.delete.refresh_list = true
    config.actions.exclude :show
    config.columns = [:branch_name,:name, :value, :description]
    config.columns[:description].form_ui = :textarea
    # config.columns[:name].options = {:size => 30}
    config.columns[:description].options = {:cols=>37, :rows => 10}
    config.columns[:value].options = {:size => 30}
    config.columns[:branch_name].label = 'For Branch or Global'
      
#    config.action_links.add 'entries',
#           :label => 'Entries',
#           :type => :collection,
#           :controller=>"/entries",
#           :action=>"index",
#           :page => true,
#           :inline => false
#    config.action_links.add 'events',
#           :label => 'Events',
#           :type => :collection,
#           :controller=>"/events",
#           :action=>"index",
#           :page => true,
#           :inline => false
  end
  def conditions_for_collection
    ['options.branch_id is not null OR options.branch_id != ? OR name not like ?', 0, 'feed_%']
  end
end