FROM rockylinux:9

RUN dnf install -y vim git ruby jq
RUN gem install ruby-openai dotenv
