class DiscoveryController < ApplicationController
  def show
    render json: Oidc::Discovery.metadata
  end
end
