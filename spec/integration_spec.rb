require 'spec_helper'

describe "integration" do

  before(:each) do
    @worker = Resque::Worker.new(:testing)
    @worker.register_worker
    @user1 = User.create(:name => "Susan")
    @user2 = User.create(:name => "Bob")
    @post1 = @user1.posts.create(:body => "I have a cat!")
    @post2 = @user1.posts.create(:body => "I have a mouse!")
    @comment1 = @post1.comments.create(:body => "Your cat sucks!", :user => @user2)
    @comment2 = @post1.comments.create(:body => "No it doesn't!", :user => @user1)
    @comment3 = @post2.comments.create(:body => "Your mouse also sucks!", :user => @user2)
  end

  it "should increment/decrement counter caches asynchronously in batches" do
    # Should be asynchronous...
    @user1.posts_count.should == 0
    @user1.comments_count.should == 0
    @user2.posts_count.should == 0
    @user2.comments_count.should == 0
    @post1.count_of_comments.should == 0
    @post2.count_of_comments.should == 0

    # 2 for posts incrementing users' posts counts
    # 3 for comments incrementing users' comments counts
    # 3 for comments incrementing posts' comments counts
    Resque.size(:testing).should == 8

    # [ArAsyncCounterCache::IncrementCountersWorker, "User", 1, "posts_count"]
    perform_next_job
    @user1.reload.posts_count.should == 2
    @user1.reload.comments_count.should == 0
    @user2.reload.posts_count.should == 0
    @user2.reload.comments_count.should == 0
    @post1.reload.count_of_comments.should == 0
    @post2.reload.count_of_comments.should == 0

    # [ArAsyncCounterCache::IncrementCountersWorker, "User", 2, "comments_count"]
    perform_next_job
    @user1.reload.posts_count.should == 2
    @user1.reload.comments_count.should == 0
    @user2.reload.posts_count.should == 0
    @user2.reload.comments_count.should == 2
    @post1.reload.count_of_comments.should == 0
    @post2.reload.count_of_comments.should == 0

    # [ArAsyncCounterCache::IncrementCountersWorker, "Post", 1, "count_of_comments"]
    perform_next_job
    @user1.reload.posts_count.should == 2
    @user1.reload.comments_count.should == 0
    @user2.reload.posts_count.should == 0
    @user2.reload.comments_count.should == 2
    @post1.reload.count_of_comments.should == 2
    @post2.reload.count_of_comments.should == 0

    # [ArAsyncCounterCache::IncrementCountersWorker, "User", 1, "comments_count"]
    perform_next_job
    @user1.reload.posts_count.should == 2
    @user1.reload.comments_count.should == 1
    @user2.reload.posts_count.should == 0
    @user2.reload.comments_count.should == 2
    @post1.reload.count_of_comments.should == 2
    @post2.reload.count_of_comments.should == 0

    # [ArAsyncCounterCache::IncrementCountersWorker, "Post", 2, "count_of_comments"]
    perform_next_job
    @user1.reload.posts_count.should == 2
    @user1.reload.comments_count.should == 1
    @user2.reload.posts_count.should == 0
    @user2.reload.comments_count.should == 2
    @post1.reload.count_of_comments.should == 2
    @post2.reload.count_of_comments.should == 1

    # Should be done...
    Resque.size(:testing).should == 0

    @comment1.destroy
    @comment2.destroy
    @comment3.destroy

    # Should be asynchronous...
    @user1.reload.posts_count.should == 2
    @user1.reload.comments_count.should == 1
    @user2.reload.posts_count.should == 0
    @user2.reload.comments_count.should == 2
    @post1.reload.count_of_comments.should == 2
    @post2.reload.count_of_comments.should == 1

    perform_all_jobs

    @user1.reload.posts_count.should == 2
    @user1.reload.comments_count.should == 0
    @user2.reload.posts_count.should == 0
    @user2.reload.comments_count.should == 0
    @post1.reload.count_of_comments.should == 0
    @post2.reload.count_of_comments.should == 0
  end

  def perform_next_job
    return unless job = @worker.reserve
    @worker.perform(job)
    @worker.done_working
  end

  def perform_all_jobs
    while job = @worker.reserve
      @worker.perform(job)
      @worker.done_working
    end
  end
end
