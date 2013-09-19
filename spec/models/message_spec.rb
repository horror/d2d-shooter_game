# == Schema Information
#
# Table name: messages
#
#  id         :integer          not null, primary key
#  user_id    :integer
#  game_id    :integer
#  text       :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

require 'spec_helper'

describe Message do

  let(:user) { FactoryGirl.create(:user) }
  before { @message = user.messages.build(text: "Example text") }

  subject { @message }

  it { should respond_to(:text) }
  it { should respond_to(:user_id) }
  it { should respond_to(:game_id) }

  it { should be_valid }

  describe "when user_id is not present" do
    before { @message.user_id = nil }
    it { should_not be_valid }
  end

end
