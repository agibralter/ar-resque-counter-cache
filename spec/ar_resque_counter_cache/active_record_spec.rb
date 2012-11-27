require 'spec_helper'

describe ArResqueCounterCache::ActiveRecord do

  context "callbacks" do

    subject { User.create(:name => "Susan") }

    it "should increment" do
      ArResqueCounterCache::IncrementCountersWorker.
        should_receive(:cache_and_enqueue).
        with("User", subject.id, "posts_count", :increment)
      subject.posts.create(:body => "I have a cat!")
    end

    it "should increment" do
      ArResqueCounterCache::IncrementCountersWorker.stub(:cache_and_enqueue)
      post = subject.posts.create(:body => "I have a cat!")
      ArResqueCounterCache::IncrementCountersWorker.
        should_receive(:cache_and_enqueue).
        with("User", subject.id, "posts_count", :decrement)
      post.destroy
    end
  end

  context "normal counter cache methods" do

    let(:user) { User.create(:name => "Bob") }

    before do
      ArResqueCounterCache::IncrementCountersWorker.stub(:cache_and_enqueue)
      user.posts.create(:body => "Foo")
      user.posts.create(:body => "Bar")
    end

    it "should allow reset_counters" do
      User.reset_counters(user.id, :posts)
      user.reload
      user.posts_count.should eq(2)
    end

    it "should allow update_counters" do
      User.update_counters(user.id, :posts_count => 10)
      user.reload
      user.posts_count.should eq(10)
    end

    it "should allow normal counter caches" do
      user.dogs.create(:name => "Ruff")
      user.reload
      user.dogs_count.should eq(1)
    end

    it "should allow non-counter caches" do
      user2 = User.create(:name => "Sam")
      cat = user.cats.create(:name => "Missy")
      # Transfership of ownership would trigger counter cache methods... it
      # should do nothing here.
      cat.user = user2
      cat.save!
      user.cats.size.should eq(0)
      user2.cats.size.should eq(1)
    end
  end
end
