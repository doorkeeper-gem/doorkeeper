require 'spec_helper_integration'


module ControllerActions
  def index
    render :text => "index"
  end

  def show
    render :text => "show"
  end
end

shared_examples "specified for particular actions" do
  context "with valid token", :token => :valid do
    it "allows into index action" do
      get :index, :access_token => token_string
      response.should be_success
    end

    it "allows into show action" do
      get :show, :id => "3", :access_token => token_string
      response.should be_success
    end
  end

  context "with invalid token", :token => :invalid do
    include_context "invalid token"

    it "does not allow into index action" do
      get :index, :access_token => token_string
      response.status.should == 401
    end

    it "allows into show action" do
      get :show, :id => "5", :access_token => token_string
      response.should be_success
    end
  end
end

shared_examples "specified with except" do
  context "with valid token", :token => :valid do
    it "allows into index action" do
      get :index, :access_token => token_string
      response.should be_success
    end

    it "allows into show action" do
      get :show, :id => "4", :access_token => token_string
      response.should be_success
    end
  end

  context "with invalid token", :token => :invalid do
    it "allows into index action" do
      get :index, :access_token => token_string
      response.should be_success
    end

    it "does not allow into show action" do
      get :show, :id => "14", :access_token => token_string
      response.status.should == 401
    end
  end
end

describe "Doorkeeper_for helper" do
  context "accepts token code specified as" do
    controller do
      doorkeeper_for :all

      def index
        render :text => "index"
      end
    end

    let :token_string do
      "1A2BC3"
    end

    it "access_token param" do
      AccessToken.should_receive(:find_by_token).with(token_string)
      get :index, :access_token => token_string
    end

    it "beareer_token param" do
      AccessToken.should_receive(:find_by_token).with(token_string)
      get :index, :bearer_token => token_string
    end

    it "Authorization header" do
      request.env["HTTP_AUTHORIZATION"] = "Bearer #{token_string}"
      get :index
    end
  end

  context "defined for all actions" do
    controller do
      doorkeeper_for :all

      include ControllerActions
    end

    context "with valid token", :token => :valid do
      it "allows into index action" do
        get :index, :access_token => token_string
        response.should be_success
      end

      it "allows into show action" do
        get :show, :id => "4", :access_token => token_string
        response.should be_success
      end
    end

    context "with invalid token", :token => :invalid do
      it "does not allow into index action" do
        get :index, :access_token => token_string
        response.status.should == 401
      end

      it "does not allow into show action" do
        get :show, :id => "4", :access_token => token_string
        response.status.should == 401
      end
    end
  end

  context "defined only for index action" do
    controller do
      doorkeeper_for :index

      include ControllerActions
    end
    include_examples "specified for particular actions"
  end

  context "defined only for index action (old syntax)" do
    controller do
      silence_warnings do
        doorkeeper_for :only => :index
      end

      include ControllerActions
    end

    include_examples "specified for particular actions"
  end

  context "defined for actions except index" do
    controller do
      doorkeeper_for :all, :except => :index

      include ControllerActions
    end

    include_examples "specified with except"
  end

  context "defined for actions except index (old syntax)" do
    controller do
      silence_warnings do
        doorkeeper_for :except => :index
      end

      include ControllerActions
    end

    include_examples "specified with except"

  end

  context "defined with scopes" do
    controller do
      doorkeeper_for :all, :scopes => [:write]

      include ControllerActions
    end

    let :token_string do
      "1A2DUWE"
    end

    it "allows if the token has particular scopes" do
      token = double(AccessToken, :accessible? => true, :scopes => [:write, :public])
      AccessToken.should_receive(:find_by_token).with(token_string).and_return(token)
      get :index, :access_token => token_string
      response.should be_success
    end

    it "does not allow if the token does not include given scope" do
      token = double(AccessToken, :accessible? => true, :scopes => [:public])
      AccessToken.should_receive(:find_by_token).with(token_string).and_return(token)
      get :index, :access_token => token_string
      response.status.should == 401
    end
  end
end
