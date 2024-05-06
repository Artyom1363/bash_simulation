FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    git \
    curl \
    bc

WORKDIR /usr/src/app