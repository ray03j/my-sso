module RequestHelpers
  def sign_in(user_id:, auth_time: Time.current.to_i)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_session_user_id).and_return(user_id)
    allow_any_instance_of(ApplicationController).to receive(:current_auth_time).and_return(auth_time)
  end
end
