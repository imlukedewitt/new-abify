require 'rails_helper'

RSpec.describe Authentication, type: :controller do
  controller(ApplicationController) do
    include Authentication

    def index
      render plain: 'success'
    end
  end

  before do
    routes.draw { get 'index' => 'anonymous#index' }
    # Clear the auto-set auth header so we can test auth logic manually
    request.headers['Authorization'] = nil
  end

  describe '#authenticate' do
    context 'with valid bearer token' do
      let!(:user) { create(:user) }

      it 'authenticates the user and allows access' do
        request.headers['Authorization'] = "Bearer #{user.api_token}"
        get :index
        expect(response).to have_http_status(:success)
        expect(response.body).to eq('success')
      end
    end

    context 'with invalid bearer token' do
      it 'returns unauthorized' do
        request.headers['Authorization'] = 'Bearer invalid_token'
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'without authorization header' do
      it 'returns unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with non-bearer authorization' do
      it 'returns unauthorized' do
        request.headers['Authorization'] = 'Basic some_credentials'
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe '#require_admin' do
    let!(:admin_user) { create(:user, role: :admin) }
    let!(:regular_user) { create(:user, role: :member) }

    controller(ApplicationController) do
      include Authentication

      before_action :require_admin

      def index
        render plain: 'admin success'
      end
    end

    before do
      routes.draw { get 'index' => 'anonymous#index' }
    end

    context 'when current user is admin' do
      it 'allows access' do
        request.headers['Authorization'] = "Bearer #{admin_user.api_token}"
        get :index
        expect(response).to have_http_status(:success)
        expect(response.body).to eq('admin success')
      end
    end

    context 'when current user is not admin' do
      it 'returns unauthorized' do
        request.headers['Authorization'] = "Bearer #{regular_user.api_token}"
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
