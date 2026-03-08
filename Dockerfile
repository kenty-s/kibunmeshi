FROM ruby:3.3

RUN apt-get update -qq && \
    apt-get install -y nodejs postgresql-client

WORKDIR /app

ARG GOOGLE_CLIENT_ID
ARG GOOGLE_CLIENT_SECRET
ENV GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
ENV GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}

COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install --jobs 4 --retry 3

COPY . .

# assets
RUN bundle exec rails tailwindcss:build
RUN bundle exec rails assets:precompile

RUN chmod +x bin/docker-entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["./bin/docker-entrypoint.sh"]
