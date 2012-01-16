require 'spec_helper'

describe ArResqueCounterCache::ActiveRecord do

  context "callbacks" do

    subject { User.create(:name => "Susan") }

    it "should increment" do
      ArResqueCounterCache::IncrementCountersWorker.should_receive(:cache_and_enqueue).with("User", subject.id, "posts_count", :increment)
      subject.posts.create(:body => "I have a cat!")
    end

    it "should increment" do
      ArResqueCounterCache::IncrementCountersWorker.stub(:cache_and_enqueue)
      post = subject.posts.create(:body => "I have a cat!")
      ArResqueCounterCache::IncrementCountersWorker.should_receive(:cache_and_enqueue).with("User", subject.id, "posts_count", :decrement)
      post.destroy
    end
  end
end
