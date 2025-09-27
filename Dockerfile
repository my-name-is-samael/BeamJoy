FROM rouhim/beammp-server:latest

# Build arguments for dynamic versioning
ARG BEAMJOY_VERSION
ARG BEAMJOY_FILE_NAME
ARG DATAPACK_VERSION
ARG DATAPACK_FILE_NAME

# Switch to root for package installation and file operations
USER root

# Install dependencies and download/extract BeamJoy in a single layer
RUN apt-get update && \
    apt-get install -y wget unzip && \
    \
    # Download and extract BeamJoy
    cd /beammp/Resources && \
    wget https://github.com/my-name-is-samael/BeamJoy/releases/download/${BEAMJOY_VERSION}/${BEAMJOY_FILE_NAME} && \
    unzip ${BEAMJOY_FILE_NAME} && \
    rm ${BEAMJOY_FILE_NAME} && \
    \
    # Create directory and download/extract datapack
    mkdir -p /beammp/Resources/Server/BeamJoyData/db/scenarii && \
    cd /beammp/Resources/Server/BeamJoyData/db/scenarii && \
    wget https://github.com/my-name-is-samael/BeamJoy/releases/download/${DATAPACK_VERSION}/${DATAPACK_FILE_NAME} && \
    unzip ${DATAPACK_FILE_NAME} && \
    rm ${DATAPACK_FILE_NAME} && \
    \
    # Set proper ownership and remove russian language
    chown -R ubuntu:ubuntu /beammp/Resources/Client /beammp/Resources/Server && \
    rm -f /beammp/Resources/Server/BeamJoyCore/lang/ru.json

# Set working directory and switch back to ubuntu user
WORKDIR /beammp
USER ubuntu
