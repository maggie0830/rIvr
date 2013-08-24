require 'dropbox'
require 'open-uri'
require 'builder'

class Vote < Template
  validates :identifier, :presence => true, :length => {:minimum=>4, :maximum => 40 }
end