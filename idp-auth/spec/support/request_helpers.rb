module RequestHelpers
  def sign_in(user_id:)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_session_user_id).and_return(user_id)
  end
end
