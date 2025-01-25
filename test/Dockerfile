FROM ubuntu:22.04

# Install required dependencies
RUN apt-get update && apt-get install -y \
    parallel \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /test