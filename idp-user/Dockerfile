FROM ruby:3.4.13
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
