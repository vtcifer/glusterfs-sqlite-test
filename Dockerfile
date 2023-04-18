# To build on different base images / tags pass the following during build
#   --build-arg BASE={base}
#   --build-arg TAG={tag}
# some examples:
#   --build-arg BASE=ruby  --build-arg TAG=slim-bullseye
#       ruby:slim-bullseye        # will be latest ruby version, currently 3.2 as of 2023.04.18
#   --build-arg BASE=ruby  --build-arg TAG=3.2-slim-bullseye
#       ruby:3.2-slim-bullseye    # locked to ruby 3.2.x
#   --build-arg BASE=debian  --build-arg TAG=bullseye-slim
#       debian:bullseye-slim      # would need ruby installed, need to update installed packages below
#   --build-arg BASE=ubuntu  --build-arg TAG=jammy
#       ubuntu:jammy              # would need ruby installed, need to update installed packages below

ARG BASE=ruby
ARG TAG=slim
FROM ${BASE}:${TAG}

# update apt-get cache
#         install required packages + tools \
#         install development packages needed for gems \
#         install gems (minimally, keep image as small as posisble, and install to correct dir for use)
#         remove development packages to keep space down \
#         clean-up
RUN export DEBIAN_FRONTEND=noninteractive && \
  apt-get -y update \
&& \
  apt-get -qy install \
    sqlite3 \
&& \
  apt-get -qy install \
    build-essential \
&& \
  gem install \
    --no-document \
    --conservative \
    --minimal-deps \
    --install-dir /usr/local/lib/ruby/gems/${RUBY_MAJOR}.0/ \
      sqlite3 \
&& \
  apt-get purge -qy --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    build-essential \
&& \
  apt-get -qy clean && rm -rf /var/lib/apt/lists/*

ADD entrypoint/* /entrypoint/

CMD [ "/entrypoint/testdb.rb" ]
